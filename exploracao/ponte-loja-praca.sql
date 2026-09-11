-- =====================================================================
--  PONTE LOJA x PRACA  |  Tarefa 3
--  Consultas usadas para montar a bridge_loja_praca: a ligacao N:N
--  entre loja e praca, com o fator de rateio do publico dentro.
--  O INSERT definitivo esta no 03-dimensoes.sql.
-- =====================================================================

-- Quais lojas atendem mais de uma praça?
SELECT "CodLoja", COUNT(*) AS em_quantas_pracas
FROM stg_loja_praca
GROUP BY "CodLoja"
HAVING COUNT(*) > 1
ORDER BY 1;
-- 16 lojas atendem mais de uma praça

-- Os fatores somam 1,00 em cada loja?
SELECT "CodLoja", SUM(CAST("PercentualPublico" AS DECIMAL(6,4))) AS soma
FROM stg_loja_praca
GROUP BY "CodLoja"
HAVING SUM(CAST("PercentualPublico" AS DECIMAL(6,4))) <> 1;
-- Resultado vazio

-- Prévia do JOIN, antes de inserir
SELECT lp."CodLoja",
       dp.sk_praca,
       CAST(lp."PercentualPublico" AS DECIMAL(6,4)) AS fator
FROM stg_loja_praca lp
JOIN dim_praca dp ON dp.cod_praca = lp."CodPraca"
ORDER BY 1, 2;

-- Validação depois do INSERT
SELECT COUNT(*) FROM bridge_loja_praca;
-- RESULTADO 48

SELECT cod_loja, ROUND(SUM(fator_publico), 4) AS soma
FROM bridge_loja_praca
GROUP BY cod_loja
HAVING ROUND(SUM(fator_publico), 4) <> 1;
-- RESULTADO vazio

SELECT COUNT(DISTINCT cod_loja) AS lojas,
       COUNT(DISTINCT sk_praca) AS pracas
FROM bridge_loja_praca;
-- RESULTADO 32 lojas, 12 pracas