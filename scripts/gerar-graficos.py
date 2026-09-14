# -*- coding: utf-8 -*-
"""
Gera os graficos do README a partir do banco dw_pata_amiga.

Rode depois do 04-fato.sql, a partir da raiz do repositorio:

    python scripts/gerar-graficos.py

Dependencias: matplotlib, pandas, psycopg2-binary.
A conexao usa o pgpass do PostgreSQL (nenhuma senha no codigo).
As imagens sao gravadas em imagens/.
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
import psycopg2
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "imagens")
os.makedirs(OUT, exist_ok=True)

SURFACE = "#fcfcfb"
INK     = "#0b0b0b"
INK2    = "#52514e"
GRID    = "#e3e2de"
S1, S2, S3 = "#2a78d6", "#eb6834", "#1baf7a"   # slots categoricos 1,2,3

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE, "font.size": 10,
    "text.color": INK, "axes.labelcolor": INK2, "axes.edgecolor": GRID,
    "xtick.color": INK2, "ytick.color": INK2,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.titlesize": 12, "axes.titleweight": "bold", "axes.titlecolor": INK,
})

conn = psycopg2.connect(host="localhost", dbname="dw_pata_amiga", user="postgres")

def q(sql):
    return pd.read_sql_query(sql, conn)

def salvar(fig, nome):
    caminho = os.path.join(OUT, nome)
    fig.savefig(caminho, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print("gravado:", nome)


# ---------------------------------------------------------------- P1
df = q("""
SELECT l.porte,
       ROUND(AVG(f.dias_integracao_separacao),2) AS a,
       ROUND(AVG(f.dias_separacao_nota),2)       AS b,
       ROUND(AVG(f.dias_nota_despacho),2)        AS c,
       ROUND(AVG(f.dias_despacho_entrega),2)     AS d
FROM fato_pedido f JOIN dim_loja l ON l.sk_loja=f.sk_loja
WHERE l.porte <> 'Nao Informado'
GROUP BY l.porte ORDER BY l.porte
""").set_index("porte").astype(float)

etapas = ["Integração\n→ Separação", "Separação\n→ Nota",
          "Nota\n→ Despacho", "Despacho\n→ Entrega"]
ordem = ["Grande", "Media", "Pequena"]
cores = {"Grande": S1, "Media": S2, "Pequena": S3}

fig, ax = plt.subplots(figsize=(9, 4.6))
larg = 0.26
for i, porte in enumerate(ordem):
    vals = df.loc[porte, ["a", "b", "c", "d"]].values
    x = [j + (i - 1) * larg for j in range(4)]
    bars = ax.bar(x, vals, larg * 0.92, label=porte, color=cores[porte], linewidth=0)
    for b, v in zip(bars, vals):
        ax.text(b.get_x() + b.get_width()/2, v + 0.15, f"{v:.2f}".replace(".", ","),
                ha="center", va="bottom", fontsize=8.5, color=INK2)

ax.set_xticks(range(4)); ax.set_xticklabels(etapas, fontsize=9)
ax.set_ylabel("dias (média)")
ax.set_title("P1 — O gargalo está entre a nota fiscal e o despacho")
ax.set_ylim(0, 10)
ax.yaxis.grid(True, color=GRID, linewidth=0.8); ax.set_axisbelow(True)
ax.legend(frameon=False, title="Porte da loja", title_fontsize=9, ncol=3,
          loc="upper left", bbox_to_anchor=(0, 1.0))
salvar(fig, "p1-gargalo-por-porte.png")


# ---------------------------------------------------------------- P2
df = q("""
SELECT c.nome_categoria AS cat, SUM(f.vl_liquido) AS fat,
       100.0*SUM(f.vl_liquido)/(SELECT SUM(vl_liquido) FROM fato_pedido) AS pct
FROM fato_pedido f JOIN dim_categoria c ON c.sk_categoria=f.sk_categoria
GROUP BY 1 ORDER BY fat
""")
fig, ax = plt.subplots(figsize=(8, 4.2))
bars = ax.barh(df["cat"], df["fat"]/1000, color=S1, linewidth=0, height=0.68)
for b, f_, p in zip(bars, df["fat"], df["pct"]):
    ax.text(b.get_width() + 12, b.get_y() + b.get_height()/2,
            f"R$ {f_/1000:,.0f} mil   ({p:.1f}%)".replace(",", "."),
            va="center", fontsize=9, color=INK2)
ax.set_xlabel("faturamento (R$ mil)")
ax.set_title("P2 — Ração responde por 60% do faturamento da rede")
ax.set_xlim(0, 1400)
ax.xaxis.grid(True, color=GRID, linewidth=0.8); ax.set_axisbelow(True)
salvar(fig, "p2-faturamento-categoria.png")


# ---------------------------------------------------------------- P3
df = q("""
SELECT canal_pedido AS canal, houve_desconto AS desc, AVG(vl_liquido) AS ticket
FROM fato_pedido
WHERE canal_pedido <> 'Nao Informado' AND houve_desconto <> 'Nao Informado'
GROUP BY 1,2
""")
piv = df.pivot(index="canal", columns="desc", values="ticket").astype(float)
piv = piv.loc[["App", "Site", "Loja Fisica", "WhatsApp", "Telefone"]]

fig, ax = plt.subplots(figsize=(9, 4.4))
larg = 0.36
x = range(len(piv))
b1 = ax.bar([i - larg/2 for i in x], piv["Sim"], larg*0.94,
            label="Com desconto", color=S1, linewidth=0)
b2 = ax.bar([i + larg/2 for i in x], piv["Nao"], larg*0.94,
            label="Sem desconto", color=S2, linewidth=0)
for bars in (b1, b2):
    for b in bars:
        ax.text(b.get_x()+b.get_width()/2, b.get_height()+8,
                f"{b.get_height():,.0f}".replace(",", "."),
                ha="center", va="bottom", fontsize=8.5, color=INK2)
ax.set_xticks(list(x)); ax.set_xticklabels(piv.index, fontsize=9.5)
ax.set_ylabel("ticket médio (R$)")
ax.set_title("P3 — O desconto não derruba o ticket em canal nenhum")
ax.set_ylim(0, 620)
ax.yaxis.grid(True, color=GRID, linewidth=0.8); ax.set_axisbelow(True)
ax.legend(frameon=False, ncol=2, loc="upper right")
salvar(fig, "p3-desconto-por-canal.png")


# ---------------------------------------------------------------- P4
df = q("""
SELECT pr.nome_praca AS praca,
       SUM(f.vl_liquido*b.fator_publico)/pr.domicilios_com_pet AS por_dom
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja=f.sk_loja
JOIN bridge_loja_praca b ON b.cod_loja=l.cod_loja
JOIN dim_praca pr ON pr.sk_praca=b.sk_praca
GROUP BY 1, pr.domicilios_com_pet ORDER BY por_dom
""")
fig, ax = plt.subplots(figsize=(8, 4.6))
bars = ax.barh(df["praca"], df["por_dom"].astype(float), color=S1,
               linewidth=0, height=0.68)
for b, v in zip(bars, df["por_dom"].astype(float)):
    ax.text(b.get_width()+0.06, b.get_y()+b.get_height()/2,
            f"R$ {v:.2f}".replace(".", ","), va="center",
            fontsize=9, color=INK2)
ax.set_xlabel("faturamento rateado por domicílio com pet (R$)")
ax.set_title("P4 — Foz do Itajaí é o maior mercado com o pior aproveitamento")
ax.set_xlim(0, 5.1)
ax.xaxis.grid(True, color=GRID, linewidth=0.8); ax.set_axisbelow(True)
salvar(fig, "p4-faturamento-por-praca.png")


# ---------------------------------------------------------------- P5
df = q("""
SELECT l.cidade, l.populacao_cidade AS pop,
       1000.0*SUM(f.qt_itens)/l.populacao_cidade AS itens_mil
FROM fato_pedido f JOIN dim_loja l ON l.sk_loja=f.sk_loja
WHERE f.sk_loja <> -1
GROUP BY 1,2 ORDER BY itens_mil DESC
""").astype({"pop": float})
df["itens_mil"] = df["itens_mil"].astype(float)

fig, ax = plt.subplots(figsize=(8.4, 4.6))
ax.scatter(df["pop"]/1000, df["itens_mil"], s=64, color=S1,
           edgecolor=SURFACE, linewidth=2, zorder=3)
desloca = {"Joinville": (-10, -16), "Florianópolis": (-10, 6)}
for _, r in df.iterrows():
    cid = r["cidade"]
    if r["itens_mil"] > 25 or cid in desloca:
        dx, dy = desloca.get(cid, (8, 3))
        ax.annotate(cid, (r["pop"]/1000, r["itens_mil"]),
                    textcoords="offset points", xytext=(dx, dy),
                    ha="right" if cid in desloca else "left",
                    fontsize=8.5, color=INK2)
ax.set_xscale("log")
ax.set_xlim(8, 900)
ax.set_xlabel("população da cidade (mil habitantes, escala log)")
ax.set_ylabel("itens vendidos por mil habitantes")
ax.set_title("P5 — A penetração cai conforme a cidade cresce")
ax.grid(True, color=GRID, linewidth=0.8); ax.set_axisbelow(True)
salvar(fig, "p5-penetracao-por-cidade.png")

conn.close()
print("\nconcluido")
