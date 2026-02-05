from flask import Flask, jsonify, request
from flask_cors import CORS
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin
import os
from google import genai
from PIL import Image
from dotenv import load_dotenv 
import json
from collections import defaultdict
from sqlalchemy import or_

# ------------------------------------------------------------------
# 1. 設定と準備
# ------------------------------------------------------------------

load_dotenv()

app = Flask(__name__, static_folder='static_web')
app.json.ensure_ascii = False

# データベース設定
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or 'postgresql://student:password@localhost/banana_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

CORS(app)
db.init_app(app)

GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')


def get_group_header(char):
    """ひらがなの頭文字からグループ名を返す"""
    if not char: return "他"
    if 'あ' <= char <= 'お': return "あ"
    if 'か' <= char <= 'ご': return "か"
    if 'さ' <= char <= 'ぞ': return "さ"
    if 'た' <= char <= 'ど': return "た"
    if 'な' <= char <= 'の': return "な"
    if 'は' <= char <= 'ぽ': return "は"
    if 'ま' <= char <= 'も': return "ま"
    if 'や' <= char <= 'よ': return "や"
    if 'ら' <= char <= 'ろ': return "ら"
    if 'わ' <= char <= 'ん': return "わ"
    return "他"

# ---------------------------------------------------------
# ★修正: models.py の定義 (name_ja, name_zh_cn) に合わせた翻訳関数
# ---------------------------------------------------------
def get_translated_value(item, field_base, lang):
    """
    item: 行データ (例: TrashDictionaryのインスタンス)
    field_base: 'name' や 'note'
    lang: 'ja', 'en', 'zh'
    """
    
    # 1. ターゲットのカラム名を決定
    target_col = f"{field_base}_{lang}" # 基本: name_en, name_ja

    # 中国語の特別対応 (zh -> zh_cn)
    if lang == 'zh':
        target_col = f"{field_base}_zh_cn"
    
    # 2. そのカラムの値を取得してみる
    val = getattr(item, target_col, None)
    
    # 3. 値があれば返す
    if val and str(val).strip():
        return val
        
    # 4. なければ日本語 (name_ja) を返す
    fallback_col = f"{field_base}_ja"
    return getattr(item, fallback_col, '')


# ------------------------------------------------------------------
# 2. ルート設定 (Routes)
# ------------------------------------------------------------------

@app.route('/')
def index():
    return "Banana Server is Running!"


# 機能A: カレンダー
@app.route('/api/schedules', methods=['GET'])
def get_schedules():
    year = request.args.get('year', type=int)
    month = request.args.get('month', type=int)
    area_id = request.args.get('area', type=int)
    lang = request.args.get('lang', 'ja') 

    if not year or not month or not area_id:
        return jsonify({"error": "year, month, and area are required"}), 400

    schedules = Schedule.query.filter_by(
        area_id=area_id,
        year=year,
        month=month
    ).all()

    result = []
    for s in schedules:
        # TrashTypeの翻訳 (name_ja, name_zh_cn等を探す)
        type_name = get_translated_value(s.trash_type, 'name', lang)
        
        result.append({
            "date": s.date.strftime('%Y-%m-%d'),
            "type": type_name,
        })
    return jsonify(result)


# 機能B: エリア
@app.route('/api/areas', methods=['GET'])
def get_areas():
    areas = Area.query.all()
    # エリア名も多言語対応が必要なら get_translated_value を使う
    # ここでは簡易的に name_ja を返す例
    return jsonify([{"id": a.id, "name": a.name_ja} for a in areas])


# 機能C: マップ
@app.route('/api/trash_bins', methods=['GET'])
def get_trash_bins():
    bins = TrashBin.query.all()
    return jsonify([{
        "id": b.id,
        "name": b.name, # TrashBinは name だけのようなのでそのまま
        "lat": b.latitude,
        "lng": b.longitude,
        "type": b.bin_type,
        "address": b.address
    } for b in bins])


# ---------------------------------------------------------
# 機能D: 分別辞書リスト (全件取得・多言語対応版)
# ---------------------------------------------------------
@app.route('/api/trash_dictionary', methods=['GET'])
def get_trash_dictionary():
    lang = request.args.get('lang', 'ja')
    
    items = TrashDictionary.query.all()
    grouped_data = defaultdict(list)
    
    for item in items:
        # 名前と備考を翻訳して取得
        name_translated = get_translated_value(item, 'name', lang)
        note_translated = get_translated_value(item, 'note', lang)
        
        if not name_translated:
            continue

        # ヘッダー（あ行、A, B...）の決定
        if lang == 'ja':
            yomi = getattr(item, 'read', getattr(item, 'yomi', ''))
            # 読みがなければ名前を使う
            if not yomi: yomi = name_translated
            header = get_group_header(yomi[0])
        else:
            first_char = name_translated[0].upper()
            if 'A' <= first_char <= 'Z':
                header = first_char
            else:
                header = '#'

        # ゴミ種類の翻訳
        type_name = ""
        if item.trash_type:
            type_name = get_translated_value(item.trash_type, 'name', lang)

        data = {
            "id": item.id,
            "name": name_translated,
            "type": type_name,
            "note": note_translated,
            "trash_type_id": item.trash_type_id
        }
        
        grouped_data[header].append(data)

    # ソートしてリスト化
    result = []
    sorted_headers = sorted(grouped_data.keys())
    
    for header in sorted_headers:
        items_list = sorted(grouped_data[header], key=lambda x: x['name'].upper())
        result.append({
            'header': header,
            'items': items_list
        })

    return jsonify(result)


# ---------------------------------------------------------
# 機能E: 検索 (多言語対応版)
# ---------------------------------------------------------
@app.route('/api/trash_search', methods=['GET'])
def trash_search():
    query_str = request.args.get('q', '')
    cat_id = request.args.get('cat_id')
    lang = request.args.get('lang', 'ja')

    base_query = TrashDictionary.query

    if cat_id:
        base_query = base_query.filter(TrashDictionary.trash_type_id == cat_id)

    if query_str:
        search_term = f"%{query_str}%"
        filters = []
        
        # 1. 日本語 (name_ja, yomi, name_kana) を検索
        if hasattr(TrashDictionary, 'name_ja'):
            filters.append(TrashDictionary.name_ja.ilike(search_term))
        if hasattr(TrashDictionary, 'yomi'):
            filters.append(TrashDictionary.yomi.ilike(search_term))
        if hasattr(TrashDictionary, 'name_kana'):
            filters.append(TrashDictionary.name_kana.ilike(search_term))
        
        # 2. 現在の言語 (name_zh_cn や name_en) も検索
        target_col_name = f"name_{lang}"
        if lang == 'zh': target_col_name = "name_zh_cn"
        
        if hasattr(TrashDictionary, target_col_name):
            col = getattr(TrashDictionary, target_col_name)
            filters.append(col.ilike(search_term))
        
        if filters:
            base_query = base_query.filter(or_(*filters))

    items = base_query.all()

    result = []
    for item in items:
        # 名前、種類、備考を翻訳してセット
        name_val = get_translated_value(item, 'name', lang)
        note_val = get_translated_value(item, 'note', lang)
        
        type_name = ""
        if item.trash_type:
            type_name = get_translated_value(item.trash_type, 'name', lang)

        result.append({
            "id": item.id,
            "name": name_val,
            "type": type_name,
            "note": note_val,
            "trash_type_id": item.trash_type_id,
        })
    
    result.sort(key=lambda x: x['name'].upper())

    return jsonify(result)


# 機能F: AI判定
@app.route('/api/predict_trash', methods=['POST'])
def predict_trash():
    if 'image' not in request.files:
        return jsonify({"error": "No image part"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    try:
        if not GEMINI_API_KEY:
            return jsonify({"error": "Server API Key not configured"}), 500

        img = Image.open(file.stream)
        prompt = """
        Analyze this image and identify the trash item.
        Return ONLY a JSON object with this exact format:
        {
            "name": "Item Name (Japanese)",
            "type": "Burnable/Non-burnable/Recyclable/etc (Japanese)",
            "confidence": 0.95,
            "reason": "Reason for classification (Japanese)"
        }
        """

        client = genai.Client(api_key=GEMINI_API_KEY)
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=[img, prompt]
        )

        if not response.text:
            raise Exception("AIからの応答が空でした。")

        response_text = response.text.replace('```json', '').replace('```', '').strip()
        result_json = json.loads(response_text)
        return jsonify(result_json)

    except Exception as e:
        print(e)
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)