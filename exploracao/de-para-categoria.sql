-- =====================================================================
--  DE-PARA DE CATEGORIA  |  Tarefa 3
--  Consultas usadas para descobrir como transformar as 37 grafias da
--  origem em 7 categorias padronizadas.
--  O INSERT definitivo esta no 03-dimensoes.sql.
-- =====================================================================

-- Verificando quantas grafias existem
SELECT DISTINCT "CategoriaProduto"
FROM stg_pedido
ORDER BY 1;

-- Reduzindo para identificar quantos prefixos existem
SELECT DISTINCT UPPER(SUBSTRING("CategoriaProduto", 1, 3)) AS tres_letras
FROM stg_pedido
ORDER BY 1;

-- Visualizando a padronização
SELECT DISTINCT
       "CategoriaProduto",
       CASE WHEN UPPER("CategoriaProduto") LIKE '%MED%' THEN 'Medicamento'
	   		WHEN UPPER("CategoriaProduto") LIKE '%PET%' THEN 'Petisco'
			WHEN UPPER("CategoriaProduto") LIKE '%RA%' THEN 'Racao'
	        WHEN UPPER("CategoriaProduto") LIKE '%HIG%' THEN 'Higiene'			
			WHEN UPPER("CategoriaProduto") LIKE '%BRI%' THEN 'Brinquedo'
			WHEN UPPER("CategoriaProduto") LIKE '%ACE%' THEN 'Acessorio'
			WHEN UPPER("CategoriaProduto") LIKE '%SER%' THEN 'Servico'			
            ELSE 'ainda nao classificado'
       END AS nome_padronizado
FROM stg_pedido
ORDER BY 1;

-- Verificando a quantidade de itens padronizados
SELECT DISTINCT
       CASE WHEN UPPER("CategoriaProduto") LIKE '%MED%' THEN 'Medicamento'
	   		WHEN UPPER("CategoriaProduto") LIKE '%PET%' THEN 'Petisco'
	        WHEN UPPER("CategoriaProduto") LIKE '%RA%' THEN 'Racao'
			WHEN UPPER("CategoriaProduto") LIKE '%HIG%' THEN 'Higiene'
			WHEN UPPER("CategoriaProduto") LIKE '%BRI%' THEN 'Brinquedo'
			WHEN UPPER("CategoriaProduto") LIKE '%ACE%' THEN 'Acessorio'
			WHEN UPPER("CategoriaProduto") LIKE '%SER%' THEN 'Servico'			
            ELSE 'ainda nao classificado'
       END AS nome_padronizado
FROM stg_pedido
ORDER BY 1;

-- Listando o que foi aplicado
SELECT * FROM public.dim_categoria
ORDER BY sk_categoria ASC;

-- Validando se o número de dados padronizados confere
SELECT COUNT(*) FROM dim_categoria;                        
SELECT COUNT(DISTINCT nome_categoria) FROM dim_categoria;
