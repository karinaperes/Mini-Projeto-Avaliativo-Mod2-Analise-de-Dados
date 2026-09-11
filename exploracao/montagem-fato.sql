-- =====================================================================
--  MONTAGEM DA FATO_PEDIDO  |  Tarefa 4
--  Montei a fato por etapas, testando cada uma antes de seguir.
--  O INSERT definitivo esta no 04-fato.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
--  INVESTIGACAO: o nome da loja
-- ---------------------------------------------------------------------
-- 39% dos pedidos vieram sem o codigo da loja, entao a loja precisa ser
-- encontrada pelo nome. Mas o nome tem 128 grafias diferentes.

-- Quantas grafias sobram depois de limpar o texto?
SELECT COUNT(DISTINCT "Loja-Nome") AS grafias_cruas,
       COUNT(DISTINCT
         UPPER(TRANSLATE(TRIM(REPLACE(REPLACE("Loja-Nome",'/SC',''),'  ',' ')),
               'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
       ) AS grafias_limpas
FROM stg_pedido;
-- RESULTADO: 128 viram 36.

-- Quais grafias ainda nao encontram a loja?
SELECT UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(p."Loja-Nome",'/SC',''),'  ',' ')),
             'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc')) AS limpo,
       COUNT(*) AS pedidos
FROM stg_pedido p
LEFT JOIN dim_loja dl
  ON dl.chave_loja = UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(p."Loja-Nome",'/SC',''),'  ',' ')),
                           'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
WHERE dl.chave_loja IS NULL
GROUP BY 1 ORDER BY 2 DESC;
-- RESULTADO: sobram 4.
--   PATA AMIGA JGUA DO SUL ......  43 pedidos  (abreviacao)
--   PATA AMIGA FLORIPA NORTE ....  42 pedidos  (apelido)
--   PATA AMIGA BLUMENAL CENTRO ..  41 pedidos  (erro de digitacao)
--   (vazio) .....................   3 pedidos  (sem nome na origem)
-- DECISAO: as tres primeiras resolvi com um CASE escrito a mao.
-- A quarta vai para a linha -1: o dado nao existe.


-- ---------------------------------------------------------------------
--  ETAPA 1: numero do pedido e as duas datas
-- ---------------------------------------------------------------------
-- A chave da dim_tempo e a data virada numero: 20231116.
-- As duas datas vem em formatos diferentes:
--   DtHoraPedido ..... 09/01/2023 10:07 AM  (americano)
--   DtEntregaCliente . 2023-09-02           (ISO)
-- Entrega em branco vai para a -1.
SELECT "NumeroPedido" AS numero_pedido,
       TO_CHAR(TO_TIMESTAMP("DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int AS sk_tempo_pedido,
       CASE WHEN "DtEntregaCliente" = '' THEN -1
            ELSE TO_CHAR("DtEntregaCliente"::date, 'YYYYMMDD')::int
       END AS sk_tempo_entrega
FROM stg_pedido;
-- RESULTADO: 4044 linhas, 1953 com entrega -1.


-- ---------------------------------------------------------------------
--  ETAPA 2: a sk_loja
-- ---------------------------------------------------------------------
-- A limpeza do nome acontece dentro do ON, antes da comparacao.
-- E LEFT JOIN: com JOIN os 3 pedidos sem nome sumiriam.
-- Quando nao acha a loja, grava -1.
SELECT p."NumeroPedido" AS numero_pedido,
       TO_CHAR(TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int AS sk_tempo_pedido,
       CASE WHEN p."DtEntregaCliente" = '' THEN -1
            ELSE TO_CHAR(p."DtEntregaCliente"::date, 'YYYYMMDD')::int
       END AS sk_tempo_entrega,
       CASE WHEN dl.sk_loja IS NULL THEN -1 ELSE dl.sk_loja END AS sk_loja
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
     END;
-- RESULTADO: 4044 linhas, 3 pedidos na loja -1.


-- ---------------------------------------------------------------------
--  ETAPA 3: a sk_categoria
-- ---------------------------------------------------------------------
-- Aqui o JOIN e de uma linha so, porque a dim_categoria guarda a grafia
-- crua em categoria_origem. A limpeza ja foi feita na dimensao.
SELECT p."NumeroPedido" AS numero_pedido,
       TO_CHAR(TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int AS sk_tempo_pedido,
       CASE WHEN p."DtEntregaCliente" = '' THEN -1
            ELSE TO_CHAR(p."DtEntregaCliente"::date, 'YYYYMMDD')::int
       END AS sk_tempo_entrega,
       CASE WHEN dl.sk_loja IS NULL THEN -1 ELSE dl.sk_loja END AS sk_loja,
       CASE WHEN dc.sk_categoria IS NULL THEN -1 ELSE dc.sk_categoria END AS sk_categoria
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
LEFT JOIN dim_categoria dc
  ON dc.categoria_origem = p."CategoriaProduto";
-- RESULTADO: 4044 linhas, nenhuma categoria na -1.


-- ---------------------------------------------------------------------
--  ETAPA 4: desconto, canal, data, itens e valor
-- ---------------------------------------------------------------------
-- Desconto e canal nao viram dimensao: sao poucos valores e nada esta
-- pendurado neles, entao ficam na propria fato, padronizados aqui.
-- No desconto uso TRANSLATE por causa de 'Nao' com til.
-- No canal a ordem importa: WHATSAPP contem APP, entao WHATS vem antes.
-- Nos numeros, vazio e '-' viram NULL, nunca 0.
SELECT p."NumeroPedido" AS numero_pedido,
       TO_CHAR(TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int AS sk_tempo_pedido,
       CASE WHEN p."DtEntregaCliente" = '' THEN -1
            ELSE TO_CHAR(p."DtEntregaCliente"::date, 'YYYYMMDD')::int
       END AS sk_tempo_entrega,
       CASE WHEN dl.sk_loja IS NULL THEN -1 ELSE dl.sk_loja END AS sk_loja,
       CASE WHEN dc.sk_categoria IS NULL THEN -1 ELSE dc.sk_categoria END AS sk_categoria,

       TO_TIMESTAMP(p."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM') AS dt_pedido,

       CASE WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"),
                       'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
                 IN ('S','SIM','1','X','TRUE','V') THEN 'Sim'
            WHEN UPPER(TRANSLATE(TRIM(p."HouveDesconto"),
                       'ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç','AAAAEEIOOOUUCaaaaeeiooouuc'))
                 IN ('N','NAO','0','FALSE','F') THEN 'Nao'
            ELSE 'Nao Informado' END AS houve_desconto,

       CASE WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%WHATS%' THEN 'WhatsApp'
            WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%APP%'   THEN 'App'
            WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%SITE%'  THEN 'Site'
            WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%LOJA%'  THEN 'Loja Fisica'
            WHEN UPPER(TRIM(p."CanalPedido")) LIKE '%TEL%'   THEN 'Telefone'
            ELSE 'Nao Informado' END AS canal_pedido,

       CASE WHEN TRIM(p."QTD.Itens") IN ('','-') THEN NULL
            ELSE CAST(p."QTD.Itens" AS INTEGER) END AS qt_itens,

       CASE WHEN TRIM(REPLACE(p."ValorLiquidoPedido(R$)",'R$','')) IN ('','-') THEN NULL
            WHEN p."ValorLiquidoPedido(R$)" LIKE '%,%'
                 THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)",'R$',''),' ',''),'.',''),',','.') AS DECIMAL(15,2))
            ELSE CAST(REPLACE(REPLACE(p."ValorLiquidoPedido(R$)",'R$',''),' ','') AS DECIMAL(15,2)) END AS vl_liquido
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
LEFT JOIN dim_categoria dc
  ON dc.categoria_origem = p."CategoriaProduto";
-- RESULTADO: 4044 linhas.
--   desconto ..... Sim 3316 / Nao 530 / Nao Informado 198
--   canal ........ App 1273 / Site 1032 / Loja Fisica 824 /
--                  WhatsApp 414 / Telefone 264 / Nao Informado 237
--   qt_itens ..... 3787 preenchidos (o resto NULL)
--   vl_liquido ... 3923 preenchidos, somando 1.793.309


-- ---------------------------------------------------------------------
--  ETAPA 5: as cinco colunas de dias
-- ---------------------------------------------------------------------
-- Em PostgreSQL, data - data ja devolve o numero de dias.
-- Sao 4 intervalos do processo mais o TOTAL (o ultimo nao e intervalo,
-- e o processo inteiro - e ele que responde a P1).
-- Se o marco de FIM estiver em branco, grava NULL, nunca 0: AVG ignora
-- NULL mas soma o zero, e o zero faria o gargalo parecer mais rapido.
-- Conferi antes que nunca existe marco de fim preenchido com o de
-- inicio em branco, entao basta testar o de fim.
SELECT
  CASE WHEN "Dt Separacao Estoque" = '' THEN NULL
       ELSE "Dt Separacao Estoque"::date
            - TO_TIMESTAMP("DtHoraIntegracaoERP",'MM/DD/YYYY HH12:MI AM')::date
       END AS dias_integracao_separacao,
  CASE WHEN "DtNotaFiscal" = '' THEN NULL
       ELSE "DtNotaFiscal"::date - "Dt Separacao Estoque"::date
       END AS dias_separacao_nota,
  CASE WHEN "Dt_Despacho_Transportadora" = '' THEN NULL
       ELSE "Dt_Despacho_Transportadora"::date - "DtNotaFiscal"::date
       END AS dias_nota_despacho,
  CASE WHEN "DtEntregaCliente" = '' THEN NULL
       ELSE "DtEntregaCliente"::date - "Dt_Despacho_Transportadora"::date
       END AS dias_despacho_entrega,
  CASE WHEN "DtEntregaCliente" = '' THEN NULL
       ELSE "DtEntregaCliente"::date
            - TO_TIMESTAMP("DtHoraIntegracaoERP",'MM/DD/YYYY HH12:MI AM')::date
       END AS dias_total_ate_entrega
FROM stg_pedido;
-- RESULTADO: os NULL batem com o diagnostico da Tarefa 1:
--   1077 / 1338 / 1665 / 1953. Nenhum dia negativo.
-- Medias: 2,13 / 0,64 / 4,11 / 2,14  -  total 9,00 dias.
-- O maior intervalo e nota -> despacho. O gargalo nao esta na entrega.
