# Pata Amiga — Modelagem Dimensional em SQL

Mini-Projeto Avaliativo do Módulo 2 — Análise de Dados com Python [T1]

---

## 1. O case

A **Pata Amiga** é uma rede catarinense de pet shops: 32 lojas, de Itapoá a São
Miguel do Oeste. Em setembro de 2023 a rede ligou a operação de pedidos com
entrega — app, site, telefone, WhatsApp e loja física — e em sete meses
registrou **4.044 pedidos**.

O dado existe, mas mora em três sistemas que não conversam: a plataforma de
e-commerce (pedidos e marcos da entrega), o cadastro de lojas do franchising e
a planilha de praças de atendimento. Cada um escreve do seu jeito — a mesma
loja aparece com acento, sem acento, em caixa alta e com erro de digitação; a
mesma categoria tem várias grafias; data e dinheiro chegam como texto.

O objetivo deste projeto é construir o **modelo dimensional** que torna as cinco
perguntas de negócio abaixo respondíveis.

| # | Pergunta de negócio |
|---|---|
| **P1** | Onde está o gargalo do processo de entrega, e ele é o mesmo nos três portes de loja? |
| **P2** | Qual categoria de produto concentra o faturamento da rede? |
| **P3** | O desconto funciona igual em todo canal de venda? |
| **P4** | Qual praça de atendimento concentra o faturamento, uma vez aplicado o rateio? |
| **P5** | Onde abrir a próxima loja — e o que os dados **não** permitem afirmar? |

---

## 2. Como reproduzir

### Pré-requisitos

- **PostgreSQL 16 ou superior** (desenvolvido e testado na versão 17.9).
- O **`psql`** acessível no terminal. O instalador do PostgreSQL no Windows nem
  sempre acrescenta a pasta `bin` ao `PATH`; confira com:

  ```powershell
  psql --version
  ```

  Se o terminal não reconhecer o comando, acrescente a pasta `bin` da sua
  instalação ao `PATH` do usuário (ajuste a letra do disco se for diferente):

  ```powershell
  $antigo = [Environment]::GetEnvironmentVariable("Path","User")
  [Environment]::SetEnvironmentVariable("Path", $antigo + ";C:\Program Files\PostgreSQL\17\bin", "User")
  ```

  A alteração só vale para terminais abertos **depois** dela — feche e reabra o
  terminal antes de testar de novo.

### Por que pelo `psql`, e não pelo pgAdmin

O `01-carga-staging.sql` cria o banco e, em seguida, **troca a conexão para ele**
com `\c dw_pata_amiga`. O `\c` não é SQL: é um meta-comando do `psql`. O editor
de query do pgAdmin não o interpreta — ele acusaria erro de sintaxe ali e as
milhares de linhas seguintes seriam carregadas no banco errado.

Portanto: **o arquivo 01 precisa ser executado pelo `psql`.** Os demais são SQL
puro e rodam em qualquer cliente.

### Ordem de execução

Na pasta do repositório:

```powershell
$env:PGCLIENTENCODING = "UTF8"

psql -U postgres -d postgres       -v ON_ERROR_STOP=1 -f 01-carga-staging.sql
psql -U postgres -d dw_pata_amiga  -v ON_ERROR_STOP=1 -f 02-dimensoes-prontas.sql
psql -U postgres -d dw_pata_amiga  -v ON_ERROR_STOP=1 -f 03-dimensoes.sql
psql -U postgres -d dw_pata_amiga  -v ON_ERROR_STOP=1 -f 04-fato.sql
psql -U postgres -d dw_pata_amiga  -v ON_ERROR_STOP=1 -f 05-perguntas.sql
```

| Trecho do comando | Por que está aí |
|---|---|
| `PGCLIENTENCODING = "UTF8"` | Os scripts estão em UTF-8 e o console do Windows não. Sem isso, `Vale do Itajaí` entra corrompido no banco e o lookup da loja falha depois, por um motivo difícil de enxergar. |
| `-d postgres` **no 01** | O `dw_pata_amiga` ainda não existe: é o próprio script que o cria. Do 02 em diante conecta-se ao banco novo. |
| `-v ON_ERROR_STOP=1` | Sem isso o `psql` registra o erro e **segue rodando** — a carga termina incompleta com aparência de sucesso. |

O `01` derruba e recria o banco (`DROP DATABASE IF EXISTS`), então a sequência
pode ser repetida do zero quantas vezes for preciso. Se aparecer
`database "dw_pata_amiga" is being accessed by other users`, feche a conexão
aberta no pgAdmin e rode de novo.

### Conferência

O `00-conferencia.sql` não faz parte da entrega: é o arquivo de verificação. Ele
está dividido em blocos, um por etapa, com o valor esperado ao lado de cada
consulta. Rode o bloco correspondente logo depois de cada script — os arquivos
dependem uns dos outros, e um número fora do lugar aqui vira resposta errada na
seção 6.

### Senha sem prompt (opcional)

O `\c` do arquivo 01 **reconecta**, e a reconexão pede a senha outra vez no meio
da execução. Para evitar a interrupção, o PostgreSQL lê credenciais de um
arquivo próprio — no Windows, `%APPDATA%\postgresql\pgpass.conf`, com uma linha
no formato `host:porta:banco:usuário:senha`:

```
localhost:5432:*:postgres:SUA_SENHA
```

Esse arquivo fica fora do repositório, no perfil do usuário. **Credencial não se
versiona.**

---

## 3. O modelo dimensional

> ⏳ *Pendente — diagrama, grão da fato e descrição das tabelas.*

---

## 4. Diagnóstico da origem

As três tabelas de staging chegaram exatamente como saíram dos sistemas de
origem: **todas as colunas em `VARCHAR`** — data é texto, valor em reais é
texto, quantidade é texto. Elas não podem ser alteradas, então todo o
tratamento acontece nos `INSERT` das dimensões e da fato.

As consultas que produziram os números abaixo estão em
[`exploracao/diagnostico-origem.sql`](exploracao/diagnostico-origem.sql).

### Volume

| Tabela | O que é | Linhas |
|---|---|---|
| `stg_pedido` | pedidos + os 4 marcos do processo de entrega | 4.044 |
| `stg_loja` | cadastro das lojas — a foto de hoje | 32 |
| `stg_loja_praca` | loja × praça de atendimento, com o % do público | 48 |

### O que está errado

| Problema | Medida | Consequência |
|---|---|---|
| **Grafias de nome de loja** | **128** para 32 lojas | o nome precisa ser padronizado **antes** do lookup |
| **Grafias de categoria** | **37** para 7 categorias | exige tabela de de-para na `dim_categoria` |
| **Pedidos sem `Cod Loja`** | **1.575** (39%) | a loja não pode ser encontrada pelo código |
| **Pedidos sem nome de loja** | **3** | vão para a linha `-1` da `dim_loja` |
| **Marcos de processo em branco** | **1.077 / 1.338 / 1.665 / 1.953** | viram `NULL`, nunca `0` |
| Grafias de `CanalPedido` | 20 para 5 canais | padronização na carga da fato |
| Grafias de `HouveDesconto` | 17 para 3 valores | padronização na carga da fato |

Os quatro marcos, em ordem: separação de estoque, nota fiscal, despacho da
transportadora e entrega ao cliente.

### Leitura dos números

**128 grafias para 32 lojas.** A mesma loja aparece com acento e sem acento,
em caixa alta e baixa, com `/SC` no fim, com espaço duplo e com erro de
digitação. Como o PostgreSQL compara byte a byte, `'Timbo'`, `'TIMBO'` e
`'Timbó'` são três textos diferentes — e nenhum deles encontra a loja no
`JOIN` sem normalização prévia dos dois lados.

**1.575 pedidos sem código de loja (39%).** Quase quatro em cada dez pedidos
não trazem o `Cod Loja`. Isso descarta o caminho óbvio — ligar pelo código —
e obriga o lookup a ser feito pelo **nome**, que é justamente o campo com 128
grafias. Os dois defeitos se combinam: é por isso que a padronização do nome
tem de vir antes do lookup, e não depois.

**37 grafias para 7 categorias**, com uma armadilha: `Ração Medicamentosa`
não é ração, é medicamento. Como a grafia contém tanto `MED` quanto `RA`, a
ordem dos testes decide o resultado — `MED` precisa ser avaliado primeiro.

**1.953 marcos de entrega em branco não são erro: são processo em aberto.**
Quase metade dos pedidos ainda não havia sido entregue no fim da janela. Esses
campos viram `NULL` nas colunas de dias, nunca `0` — a média (`AVG`) ignora
`NULL`, mas soma o zero, e um zero no lugar de "não aconteceu" faria o gargalo
da P1 parecer mais rápido do que é.

**Dois formatos de data convivem na mesma tabela.** A data do pedido vem no
padrão americano com AM/PM (`09/01/2023 10:07 AM`), porque a plataforma de
e-commerce é de fornecedor norte-americano e nunca foi localizada. Já os
quatro marcos da entrega vêm em ISO (`2023-09-02`). Cada coluna exige a sua
máscara — e usar `DD/MM/YYYY` na data do pedido faz o PostgreSQL **lançar
erro** nas datas cujo mês é maior que 12.

**Números em formatos misturados.** A mesma coluna de valor traz
`R$ 1.850,00`, `1850.00`, `1.200`, `-` e vazio. O `-` e o vazio significam
ausência de informação e viram `NULL` — gravá-los como `0` inventaria um
faturamento que não existe.

---

## 5. Decisões de tratamento

> ⏳ *Pendente — Tarefa 2: máscaras de data, regra dos números, de-para de
> categoria e padronização do nome da loja.*

---

## 6. As cinco respostas

> ⏳ *Pendente — Tarefa 5: P1 a P5, cada uma com o número e a reconciliação
> com a origem.*

---

## 7. Recomendação e limitações

> ⏳ *Pendente — onde abrir a próxima loja e o que os dados não sustentam.*

---

## 8. Vídeo

> ⏳ *Pendente — link da apresentação (até 5 minutos).*
