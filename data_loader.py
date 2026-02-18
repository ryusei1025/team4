import csv
import os
import random

# ---------------------------------------------------------
# データを保持する変数 (モジュール変数としてキャッシュ)
# ---------------------------------------------------------
_trash_dictionary = []
_trash_type_map = {}

# データセットフォルダのパス (このファイルから見た相対パス)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(BASE_DIR, 'dataset')

def load_data():
    """
    すべてのCSVデータを読み込んでメモリに準備する関数。
    app.py の起動時に一度だけ呼ばれます。
    """
    global _trash_dictionary, _trash_type_map
    
    print("--- Loading Datasets ---")

    # 1. 分別辞書の読み込み
    dict_path = os.path.join(DATASET_DIR, 'trash_dictionary_multilingual.csv')
    try:
        with open(dict_path, encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            _trash_dictionary = list(reader)
            print(f"✔ Loaded {len(_trash_dictionary)} dictionary items.")
    except Exception as e:
        print(f"✖ Error loading dictionary: {e}")
        _trash_dictionary = []

    # 2. ゴミ種類IDのマッピング (trash_types.csvを元にする場合もここで処理可能)
    # ここでは固定マップとして定義していますが、csvから読む形にも拡張できます
    _trash_type_map = {
        "燃やせるごみ": 1,
        "燃やせないごみ": 2,
        "びん・缶・ペットボトル": 3,
        "容器包装プラスチック": 4,
        "雑がみ": 5,
        "枝・葉・草": 6,
        "大型ごみ": 99, 
        "収集なし": 0
    }

def get_trash_type_map():
    """ゴミ種類マップを返す"""
    if not _trash_type_map: load_data()
    return _trash_type_map

def get_dictionary_list():
    """辞書リストそのものを返す"""
    if not _trash_dictionary: load_data()
    return _trash_dictionary

def find_in_dictionary(search_term):
    """
    辞書から用語を検索するロジック
    (app.py にあったものをここに移動)
    """
    if not _trash_dictionary: load_data()
    if not search_term: return None
    
    term = search_term.lower().strip()

    # 1. 完全一致
    for row in _trash_dictionary:
        if row.get('name_ja', '').strip() == term or \
           row.get('name_en', '').lower().strip() == term:
            return row

    # 2. 部分一致
    for row in _trash_dictionary:
        if term in row.get('name_ja', '') or \
           term in row.get('name_en', '').lower():
            return row
            
    return None

def get_random_item():
    """デモ用にランダムなゴミデータを1つ返す"""
    if not _trash_dictionary: load_data()
    if _trash_dictionary:
        return random.choice(_trash_dictionary)
    return None