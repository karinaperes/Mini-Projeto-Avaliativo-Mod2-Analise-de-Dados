-- =====================================================================
--  DIAGNOSTICO DA ORIGEM  |  Tarefa 1
--  Consultas usadas para medir o estado das tres tabelas de staging.
--  Os numeros daqui foram para a secao 4 do README.
-- =====================================================================

-- 1) As tres tabelas carregaram a quantidade certa de linhas?
SELECT 'stg_pedido' AS tabela, COUNT(*) AS linhas, 4044 AS esperado FROM stg_pedido
UNION ALL SELECT 'stg_loja',       COUNT(*), 32 FROM stg_loja
UNION ALL SELECT 'stg_loja_praca', COUNT(*), 48 FROM stg_loja_praca;
-- OK: 4044 / 32 / 48.


-- 2) Quanto a origem esta suja?
-- COUNT(DISTINCT ...) conta quantas formas diferentes de escrever existem.
-- SUM(CASE WHEN ... = '' THEN 1 ELSE 0 END) conta os campos vazios.
SELECT 'grafias distintas de categoria' AS diagnostico,
       COUNT(DISTINCT "CategoriaProduto") AS valor FROM stg_pedido
UNION ALL SELECT 'grafias distintas de nome de loja',
       COUNT(DISTINCT "Loja-Nome") FROM stg_pedido
UNION ALL SELECT 'grafias distintas de HouveDesconto',
       COUNT(DISTINCT "HouveDesconto") FROM stg_pedido
UNION ALL SELECT 'grafias distintas de CanalPedido',
       COUNT(DISTINCT "CanalPedido") FROM stg_pedido
UNION ALL SELECT 'pedidos sem Cod Loja preenchido',
       SUM(CASE WHEN "Cod Loja" = '' THEN 1 ELSE 0 END) FROM stg_pedido
UNION ALL SELECT 'pedidos sem nome de loja',
       SUM(CASE WHEN "Loja-Nome" = '' THEN 1 ELSE 0 END) FROM stg_pedido;
-- RESULTADO:
--   categoria ....... 37 grafias para 7 categorias
--   nome de loja .... 128 grafias para 32 lojas
--   CanalPedido ..... 20 grafias para 5 canais
--   HouveDesconto ... 17 grafias para 3 valores
--   sem Cod Loja .... 1575 pedidos (39%) -> o lookup tem de ser pelo NOME
--   sem nome de loja ... 3 pedidos -> vao para a linha -1 da dim_loja


-- 3) Quantos marcos do processo estao em branco?
SELECT 'Dt Separacao Estoque' AS marco,
       SUM(CASE WHEN "Dt Separacao Estoque" = '' THEN 1 ELSE 0 END) AS em_branco,
       1077 AS esperado FROM stg_pedido
UNION ALL SELECT 'DtNotaFiscal',
       SUM(CASE WHEN "DtNotaFiscal" = '' THEN 1 ELSE 0 END), 1338 FROM stg_pedido
UNION ALL SELECT 'Dt_Despacho_Transportadora',
       SUM(CASE WHEN "Dt_Despacho_Transportadora" = '' THEN 1 ELSE 0 END), 1665 FROM stg_pedido
UNION ALL SELECT 'DtEntregaCliente',
       SUM(CASE WHEN "DtEntregaCliente" = '' THEN 1 ELSE 0 END), 1953 FROM stg_pedido;
-- RESULTADO: 1077 / 1338 / 1665 / 1953.
-- Marco em branco nao e erro: e processo em aberto. Na fato vira NULL,
-- nunca 0 - um zero faria a media do tempo de entrega parecer mais rapida.
