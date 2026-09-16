-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  PostgreSQL 16
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
--
--  Regra geral: a limpeza dos dados fica nas dimensoes; a fato apenas procura a
--  linha correta (por JOIN). Nenhuma FK fica nula: quando o dado falta, ela
--  aponta para a linha -1 (CASE WHEN ... IS NULL THEN -1).
--
--  Sugestao: comece pelo esqueleto (numero_pedido + as duas FKs de tempo +
--  FROM), rode e confira 4.044 linhas; depois acrescente as colunas aos poucos.
-- =====================================================================================

INSERT INTO fato_pedido (
    numero_pedido, sk_tempo_pedido, sk_tempo_entrega, sk_loja, sk_categoria,
    houve_desconto, canal_pedido, dt_pedido, qt_itens, vl_liquido,
    dias_integracao_separacao, dias_separacao_nota, dias_nota_despacho,
    dias_despacho_entrega, dias_total_ate_entrega
)
SELECT p."NumeroPedido",
       TO_CHAR(TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int,
       CASE WHEN p."DtEntregaCliente" = '' THEN -1
            ELSE TO_CHAR(p."DtEntregaCliente"::date, 'YYYYMMDD')::int END,
       CASE WHEN dl.sk_loja IS NULL THEN -1 ELSE dl.sk_loja END,
       CASE WHEN dc.sk_categoria IS NULL THEN -1 ELSE dc.sk_categoria END,
       CASE WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"),
                       'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
                 IN ('S','SIM','1','X','TRUE','V') THEN 'Sim'
            WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"),
                       'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
                 IN ('N','NAO','0','FALSE','F') THEN 'Nao'
            ELSE 'Nao Informado' END,
       CASE WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%WHATS%' THEN 'WhatsApp'
            WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%APP%'   THEN 'App'
            WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%SITE%'  THEN 'Site'
            WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%LOJA%'  THEN 'Loja Fisica'
            WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%TEL%'   THEN 'Telefone'
            ELSE 'Nao Informado' END,
       TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'),
       CASE WHEN TRIM(p."QTD.Itens") IN ('','-') THEN NULL
            ELSE CAST(p."QTD.Itens" AS INTEGER) END,
       CASE WHEN TRIM(REPLACE(p."ValorLiquidoPedido(R$)",'R$','')) IN ('','-') THEN NULL
            WHEN p."ValorLiquidoPedido(R$)" LIKE '%,%'
                 THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)",'R$',''),' ',''),'.',''),',','.') AS DECIMAL(15,2))
            ELSE CAST(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)",'R$',''),' ','') AS DECIMAL(15,2)) END,
       CASE WHEN p."Dt Separacao Estoque" = '' THEN NULL
            ELSE p."Dt Separacao Estoque"::date
                 - TO_TIMESTAMP(p."DtHoraIntegracaoERP",'MM/DD/YYYY HH12:MI AM')::date END,
       CASE WHEN p."DtNotaFiscal" = '' THEN NULL
            ELSE p."DtNotaFiscal"::date - p."Dt Separacao Estoque"::date END,
       CASE WHEN p."Dt_Despacho_Transportadora" = '' THEN NULL
            ELSE p."Dt_Despacho_Transportadora"::date - p."DtNotaFiscal"::date END,
       CASE WHEN p."DtEntregaCliente" = '' THEN NULL
            ELSE p."DtEntregaCliente"::date - p."Dt_Despacho_Transportadora"::date END,
       CASE WHEN p."DtEntregaCliente" = '' THEN NULL
            ELSE p."DtEntregaCliente"::date
                 - TO_TIMESTAMP(p."DtHoraIntegracaoERP",'MM/DD/YYYY HH12:MI AM')::date END
FROM stg_pedido p
LEFT JOIN dim_loja dl
  ON dl.chave_loja =
     CASE UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(p."Loja-Nome",'/SC',''),'  ',' ')),
                'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
          WHEN 'PATA AMIGA BLUMENAL CENTRO' THEN 'PATA AMIGA BLUMENAU CENTRO'
          WHEN 'PATA AMIGA FLORIPA NORTE'   THEN 'PATA AMIGA FLORIANOPOLIS NORTE'
          WHEN 'PATA AMIGA JGUA DO SUL'     THEN 'PATA AMIGA JARAGUA DO SUL'
          ELSE UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(p."Loja-Nome",'/SC',''),'  ',' ')),
                     'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
     END
LEFT JOIN dim_categoria dc ON dc.categoria_origem = p."CategoriaProduto";
--
--  Roteiro das colunas:
--
--  * sk_tempo_pedido / sk_tempo_entrega: a chave e a data no formato AAAAMMDD.
--    Monte com TO_CHAR(<a data>, 'YYYYMMDD')::int. A data do PEDIDO vem no
--    formato americano com AM/PM: a mascara e 'MM/DD/YYYY HH12:MI AM'
--    (TO_TIMESTAMP). Usar 'DD/MM/YYYY' faz o PostgreSQL LANCAR ERRO nas datas
--    com mes maior que 12. Os marcos da entrega ja vem em ISO: ::date basta.
--    Entrega em branco -> -1.
--
--  * sk_loja, sk_categoria: vem de LEFT JOIN; se nao achou par, -1.
--
--  * LOJA (LEFT JOIN dim_loja): limpe o nome no ON. REPLACE tira '/SC' e o espaco
--    duplo; um CASE resolve 3 grafias (digitacao, apelido, abreviacao). O
--    PostgreSQL compara byte a byte, entao normalize acento e caixa com
--    UPPER(TRANSLATE(..., 'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç',
--    'AAAAEEIOOOUUCaaaaeeiooouuc')). A chave_loja da dim_loja ja veio em caixa
--    alta e sem acento.
--
--  * CATEGORIA (LEFT JOIN dim_categoria): uma linha so -
--    ON dc.categoria_origem = p."CategoriaProduto".
--
--  * houve_desconto e canal_pedido: padronize com CASE e grave na PROPRIA fato
--    (nao ha dimensao para eles). O de-para completo dos dois campos esta no
--    ENUNCIADO, na secao 7 ("Como padronizar o desconto e o canal").
--    A ordem importa: 'WHATSAPP' contem 'APP',
--    entao teste WHATS antes de APP. No desconto, tire o acento com TRANSLATE
--    antes do UPPER.
--
--  * dinheiro e itens: '' e '-' viram NULL; tire "R$" e trate o milhar.
--
--  * os lags em dias: em PostgreSQL, data - data ja da o numero de dias. Etapa
--    nao cumprida grava NULL, nunca 0. Use ::date em volta da integracao.

-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 04").
-- =====================================================================================
