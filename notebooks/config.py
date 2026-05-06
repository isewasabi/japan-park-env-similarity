"""
config.py
---------
Shared configuration for all notebooks.
Edit DATA_DIR and OUTPUT_DIR to match your environment.
"""
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────
DATA_DIR    = Path("../data/interim")   # h3_jpn_res9_source_imputed.parquet
OUTPUT_DIR  = Path("../data/results")   # per-park model outputs
PAPER_DIR   = Path("../paper_outputs")  # tables and figures for the manuscript

# ── Parks: Japanese name → English slug ──────────────────────────────────────
# Used ONLY in 01_preprocessing.ipynb to translate the NAME column.
# All downstream notebooks use English slugs exclusively.
PARK_NAME_MAP = {
    "利尻礼文サロベツ":    "rishiri",
    "知床":               "shiretoko",
    "阿寒摩周":           "akan",
    "釧路湿原":           "kushiro",
    "大雪山":             "taisetsu",
    "日高山脈襟裳十勝":   "hidaka",
    "支笏洞爺":           "shikotsu",
    "十和田八幡平":       "towada",
    "三陸復興":           "sanriku",
    "磐梯朝日":           "bandai",
    "日光":               "nikko",
    "尾瀬":               "oze",
    "上信越高原":         "jyoshinetsu",
    "妙高戸隠連山":       "myoko",
    "秩父多摩甲斐":       "chichibu",
    "小笠原":             "ogasawara",
    "富士箱根伊豆":       "fuji",
    "中部山岳":           "chubusangaku",
    "白山":               "hakusan",
    "南アルプス":         "minamialps",
    "伊勢志摩":           "ise",
    "吉野熊野":           "yoshino",
    "山陰海岸":           "sanin",
    "瀬戸内海":           "setonaikai",
    "大山隠岐":           "daisen",
    "足摺宇和海":         "ashizuri",
    "西海":               "saikai",
    "雲仙天草":           "unzen",
    "阿蘇くじゅう":       "aso",
    "霧島錦江湾":         "kirishima",
    "屋久島":             "yakushima",
    "奄美群島":           "amami",
    "やんばる":           "yambaru",
    "慶良間諸島":         "kerama",
    "西表石垣":           "iriomote",
}

# English slugs only — used in 02_modeling.ipynb and 03_analysis_figures.ipynb
PARKS = list(PARK_NAME_MAP.values())

# ── Model run candidates (priority order) ────────────────────────────────────
RUN_CANDIDATES = [
    "{slug}_prod_g8_gap1",
    "{slug}_prod_g8_gap1_rerun",
    "{slug}_prod_g8_gap2",
]

# ── Modeling parameters ──────────────────────────────────────────────────────
GLOBAL_SEED   = 42
GROUP_CUT     = 8    # H3 index resolution for spatial grouping
GAP_KRING     = 1    # k-ring gap size to reduce spatial leakage
OUTER_SPLITS  = 5
INNER_SPLITS  = 3
