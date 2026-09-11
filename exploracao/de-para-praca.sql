-- =====================================================================
--  DE-PARA DE PRACA  |  Tarefa 3
--  Consultas usadas para entender o grao da stg_loja_praca e reduzir
--  as 48 linhas (loja x praca) as 12 pracas da dimensao.
--  O INSERT definitivo esta no 03-dimensoes.sql.
-- =====================================================================

-- Olhando a origem para entender o grao da tabela
SELECT * FROM stg_loja_praca ORDER BY "CodPraca", "CodLoja";
-- RESULTADO: 48 linhas. O grao e "uma loja x uma praca": cada linha diz
-- que loja atende que praca, e com que fatia do publico (PercentualPublico).

-- Contando quantas pracas distintas existem
SELECT DISTINCT "CodPraca"
FROM stg_loja_praca
ORDER BY 1;
-- RESULTADO: 12 pracas.

-- Contando quantas lojas distintas existem
SELECT DISTINCT "CodLoja"
FROM stg_loja_praca
ORDER BY 1;
-- RESULTADO: 32 lojas.
-- CONCLUSAO: 32 lojas em 48 linhas = 16 lojas atendem duas pracas cada.
-- Exemplo: a LJ-013 aparece duas vezes, com 0.40 e 0.60 - somando 1.00.
-- E essa relacao N:N que justifica a tabela ponte: uma FK so comportaria
-- uma praca e a outra se perderia.

-- Listando o que foi aplicado
SELECT * FROM dim_praca
ORDER BY sk_praca ASC;

-- Validando se o numero de pracas confere
SELECT COUNT(*) FROM dim_praca;
-- ESPERADO: 13 = as 12 pracas + a linha -1
