-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Cada pergunta e UMA consulta: um SELECT com JOIN e GROUP BY. A subconsulta
--  aparece na P2 e na P5, e serve para trazer o total da rede como denominador.
--
--  ATENCAO AO POSTGRESQL: int / int TRUNCA. Nos percentuais e taxas use o fator
--  100.0 / 1000.0 (com ponto); e ROUND(x, casas) exige x numerico.
-- =====================================================================================

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.

SELECT l.porte,
       COUNT(*)                                  AS pedidos,
       ROUND(AVG(f.dias_integracao_separacao),2) AS integracao_separacao,
       ROUND(AVG(f.dias_separacao_nota),2)       AS separacao_nota,
       ROUND(AVG(f.dias_nota_despacho),2)        AS nota_despacho,
       ROUND(AVG(f.dias_despacho_entrega),2)     AS despacho_entrega,
       ROUND(AVG(f.dias_total_ate_entrega),2)    AS total_ate_entrega
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.porte
ORDER BY 1;
-- RESULTADO:
--   Grande   7,93 dias no total, gargalo em nota->despacho (3,32)
--   Pequena  15,16 dias, gargalo em nota->despacho (8,53)

-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.

SELECT c.nome_categoria,
       COUNT(*)                 AS pedidos,
       ROUND(SUM(f.vl_liquido)) AS faturamento,
       ROUND(100.0 * SUM(f.vl_liquido)
             / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS pct_do_total
FROM fato_pedido f
JOIN dim_categoria c ON c.sk_categoria = f.sk_categoria
GROUP BY c.nome_categoria
ORDER BY faturamento DESC;
-- RESULTADO:
--   Racao ......... 1.076.203  (60,01%)  1387 pedidos
--   Medicamento ...   305.904  (17,06%)   667
--   Petisco .......   128.590  ( 7,17%)   759
--   Servico .......    94.001  ( 5,24%)   269
--   Higiene .......    92.314  ( 5,15%)   507
--   Acessorio .....    64.661  ( 3,61%)   263
--   Brinquedo .....    31.635  ( 1,76%)   192
--   Total .........  1.793.309  (100%)
--
-- Racao sozinha e 60% do faturamento. Com Medicamento, 77%.
-- Petisco tem mais pedidos que Medicamento (759 x 667) mas fatura menos
-- da metade: o ticket medio e muito diferente.
-- A campea e a mesma nos tres portes. So muda da 5a posicao para baixo:
-- nas lojas pequenas, Higiene passa Servico.


-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.

SELECT canal_pedido,
       houve_desconto,
       COUNT(*)                  AS pedidos,
       ROUND(AVG(vl_liquido), 2) AS ticket_medio,
       ROUND(SUM(vl_liquido))    AS faturamento,
       ROUND(100.0 * SUM(vl_liquido)
             / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS pct_do_total
FROM fato_pedido
GROUP BY canal_pedido, houve_desconto
ORDER BY canal_pedido, houve_desconto;
-- RESULTADO: ticket medio com e sem desconto, por canal
--   Canal          com desconto   sem desconto   razao   % faturamento
--   App ..........       488,04         167,63    2,9x      30,8%
--   Site .........       501,92         189,68    2,6x      25,1%
--   Loja Fisica ..       494,04         197,55    2,5x      20,1%
--   WhatsApp .....       514,33         179,26    2,9x      10,5%
--   Telefone .....       514,02         195,23    2,6x       6,9%
--
-- O desconto NAO derruba o ticket em canal nenhum: pedidos com desconto
-- valem 2,5 a 2,9 vezes mais que os sem, nos cinco canais.
-- A politica se comporta igual em todos - nao ha canal destoante que
-- justifique tratamento diferente.
-- LIMITACAO: isso nao prova que o desconto aumenta o gasto. O mais
-- provavel e o inverso - o desconto ser concedido nas compras grandes.
-- A origem nao registra quando nem por que o desconto foi aplicado,
-- entao os dados nao permitem separar as duas hipoteses.


-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.

SELECT pr.nome_praca,
       pr.regional,
       pr.domicilios_com_pet,
       ROUND(SUM(f.vl_liquido * b.fator_publico))      AS faturamento_rateado,
       ROUND(100.0 * SUM(f.vl_liquido * b.fator_publico)
             / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS pct_do_total,
       ROUND(SUM(f.vl_liquido * b.fator_publico)
             / pr.domicilios_com_pet, 2)               AS faturamento_por_domicilio
FROM fato_pedido f
JOIN dim_loja l          ON l.sk_loja  = f.sk_loja
JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja
JOIN dim_praca pr        ON pr.sk_praca = b.sk_praca
GROUP BY pr.nome_praca, pr.regional, pr.domicilios_com_pet
ORDER BY faturamento_rateado DESC;
-- RESULTADO: faturamento rateado por praca
--   Praca                  domicilios   rateado    %       por domicilio
--   Vale do Itajai ......... 148.000    633.746   35,34%      R$ 4,28
--   Grande Florianopolis ... 132.000    283.547   15,81%      R$ 2,15
--   Norte Industrial .......  96.000    175.432    9,78%      R$ 1,83
--   Litoral Sul ............  58.000    137.051    7,64%      R$ 2,36
--   Litoral Norte ..........  61.000    128.873    7,19%      R$ 2,11
--   Extremo Oeste ..........  63.000     98.359    5,48%      R$ 1,56
--   Carbonifera ............  67.000     88.707    4,95%      R$ 1,32
--   Serra Catarinense ......  44.000     80.478    4,49%      R$ 1,83
--   Meio-Oeste .............  51.000     58.956    3,29%      R$ 1,16
--   Foz do Itajai ..........  74.000     46.750    2,61%      R$ 0,63
--   Planalto Norte .........  33.000     31.101    1,73%      R$ 0,94
--   Planalto Serrano .......  29.000     29.323    1,64%      R$ 1,01
--
-- RECONCILIACAO: 1.792.322 rateado + 986 dos pedidos sem loja
--                = 1.793.309, o faturamento da rede. Diferenca zero.
--
-- Vale do Itajai concentra 35% da rede e fatura R$ 4,28 por domicilio
-- com pet - quase o dobro da segunda colocada. E onde a rede nasceu:
-- 12 das 32 lojas estao la.
--
-- Foz do Itajai e o oposto: quarto maior mercado (74.000 domicilios) e
-- o pior aproveitamento da rede, R$ 0,63 por domicilio. A praca vizinha
-- tira R$ 4,28 do mesmo tipo de publico.
--
-- O JOIN com a ponte duplica a linha do pedido, uma por praca. Isso e
-- esperado: multiplicar por fator_publico antes de somar impede a
-- contagem dupla e faz a soma fechar com o total da rede.



-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens POR MIL HABITANTES (numerador na fato,
--      denominador na dimensao), calculado AQUI na consulta - nunca gravado
--      pronto. Cruze com o tempo medio de entrega.
--  (b) Mostre o faturamento por faixa de franquia e explique por que ele NAO
--      responde "quanto veio de lojas que JA ERAM Ouro na data do pedido": o
--      cadastro so tem a foto de hoje.
--  (c) Meca o que ficou de fora: pedidos sem loja, entregas nao concluidas,
--      itens e valores em branco.

-- (a) Lojas por itens por mil habitantes, cruzado com o tempo de entrega:
SELECT l.nome_loja, l.cidade, l.populacao_cidade,
       SUM(f.qt_itens)                                         AS itens,
       ROUND(1000.0 * SUM(f.qt_itens) / l.populacao_cidade, 2) AS itens_por_mil_hab,
       ROUND(AVG(f.dias_total_ate_entrega), 2)                 AS dias_ate_entrega
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE f.sk_loja <> -1
GROUP BY l.nome_loja, l.cidade, l.populacao_cidade
ORDER BY itens_por_mil_hab DESC;
--  Rio dos Cedros ......  11.322 hab | 41,87 itens/mil | 14,24 dias
--  Presidente Getulio ..  16.359     | 34,84           | 14,16
--  Ibirama .............  18.613     | 32,07           | 15,39
--  ...
--  Joinville Sul ....... 597.658     |  3,16           |  7,83
--  Itajai Praia ........ 264.054     |  3,02           |  7,98
--  Florianopolis Norte . 537.213     |  2,65           |  8,02

-- (b) Faturamento por faixa de franquia:
SELECT l.faixa_franquia,
       COUNT(DISTINCT l.cod_loja)  AS lojas,
       ROUND(SUM(f.vl_liquido))    AS faturamento,
       ROUND(100.0 * SUM(f.vl_liquido)
             / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS pct_do_total
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.faixa_franquia
ORDER BY faturamento DESC;
--  Ouro     | 15 lojas | 1.011.264 | 56,39%
--  Diamante |  5       |   382.210 | 21,31%
--  Prata    |  8       |   314.812 | 17,55%
--  Bronze   |  4       |    84.036 |  4,69%

-- (c) O que ficou de fora:
SELECT 'pedidos sem loja identificada' AS item,
       COUNT(*) AS qtd,
       ROUND(100.0 * COUNT(*) / 4044, 2) AS pct
FROM fato_pedido WHERE sk_loja = -1
UNION ALL SELECT 'entregas nao concluidas', COUNT(*), ROUND(100.0*COUNT(*)/4044,2)
  FROM fato_pedido WHERE sk_tempo_entrega = -1
UNION ALL SELECT 'pedidos sem quantidade de itens', COUNT(*), ROUND(100.0*COUNT(*)/4044,2)
  FROM fato_pedido WHERE qt_itens IS NULL
UNION ALL SELECT 'pedidos sem valor liquido', COUNT(*), ROUND(100.0*COUNT(*)/4044,2)
  FROM fato_pedido WHERE vl_liquido IS NULL
UNION ALL SELECT 'canal nao informado', COUNT(*), ROUND(100.0*COUNT(*)/4044,2)
  FROM fato_pedido WHERE canal_pedido = 'Nao Informado'
UNION ALL SELECT 'desconto nao informado', COUNT(*), ROUND(100.0*COUNT(*)/4044,2)
  FROM fato_pedido WHERE houve_desconto = 'Nao Informado'
ORDER BY qtd DESC;
--   entregas nao concluidas ......... 1.953  (48,29%)
--  pedidos sem quantidade de itens ... 257  ( 6,36%)
--  canal nao informado ............... 237  ( 5,86%)
--  desconto nao informado ............ 198  ( 4,90%)
--  pedidos sem valor liquido ......... 121  ( 2,99%)
--  pedidos sem loja identificada ....... 3  ( 0,07%)
