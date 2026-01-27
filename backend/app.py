from flask import Flask, jsonify, request, render_template
from flask_cors import CORS
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin
import os
import google.generativeai as genai
from PIL import Image
from dotenv import load_dotenv 
import json # AI診断の結果を処理するために必要
from collections import defaultdict # ★グループ化のために追加
from sqlalchemy import or_ # ★ひらがな・カタカナ検索のために追加

# ------------------------------------------------------------------
# 1. 設定と準備 (Configuration)
# ------------------------------------------------------------------

load_dotenv()
app = Flask(__name__)
app.json.ensure_ascii = False

# データベースの接続先を設定します (PostgreSQLに接続)
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or 'postgresql://student:password@localhost/banana_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

CORS(app)
db.init_app(app)

# Gemini API の設定
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

# ------------------------------------------------------------------
# 2. 補助関数 (Helper Functions)
# ------------------------------------------------------------------

def get_group_header(char):
    if not char: return '他'
    if 'あ' <= char <= 'お': return 'あ'
    if 'か' <= char <= 'こ' or char in 'がぎぐげご': return 'か'
    if 'さ' <= char <= 'そ' or char in 'ざじずぜぞ': return 'さ'
    if 'た' <= char <= 'と' or char in 'だぢづでど': return 'た'
    if 'な' <= char <= 'の': return 'な'
    if 'は' <= char <= 'ほ' or char in 'ばびぶべぼぱぴぷぺぽ': return 'は'
    if 'ま' <= char <= 'も': return 'ま'
    if 'や' <= char <= 'よ': return 'や'
    if 'ら' <= char <= 'ろ': return 'ら'
    if 'わ' <= char <= 'ん': return 'わ'
    return '他'

# ------------------------------------------------------------------
# 3. APIエンドポイント (Routes)
# ------------------------------------------------------------------

@app.route('/')
def index():
    return "Waste Management API is running!"

@app.route('/api/areas', methods=['GET'])
def get_areas():
    lang = request.args.get('lang', 'ja')
    areas = Area.query.all()
    result = []
    for area in areas:
        data = {"id": area.id, "name": area.get_localized_name(lang), "calendar_no": area.calendar_no}
        result.append(data)
    return jsonify(result)

@app.route('/api/schedules', methods=['GET'])
def get_schedules():
    area_id = request.args.get('area_id')
    if not area_id: return jsonify({"error": "area_id is required"}), 400
    schedules = Schedule.query.filter_by(area_id=area_id).all()
    result = []
    for sch in schedules:
        trash_type = TrashType.query.get(sch.trash_type_id)
        if trash_type:
            result.append({
                "date": sch.date.strftime('%Y-%m-%d'),
                "trash_type": {"id": trash_type.id, "name": trash_type.name_ja, "color": trash_type.color_code, "icon": trash_type.icon_name}
            })
    result.sort(key=lambda x: x['date'])
    return jsonify(result)

# =========================================================
# 機能C: ゴミ分別辞典を検索する (前方一致優先)
# =========================================================
@app.route('/api/trash_search', methods=['GET'])
def search_trash():
    keyword = request.args.get('q', '').strip()
    lang = request.args.get('lang', 'ja')     
    cat_id = request.args.get('cat_id', '')   

    if not keyword and not cat_id:
        return jsonify([])

    query_obj = TrashDictionary.query

    if cat_id:
        try:
            query_obj = query_obj.filter_by(trash_type_id=int(cat_id))
        except ValueError:
            pass

    if keyword:
        # ひらがな・カタカナ相互変換
        hira_keyword = "".join([chr(ord(c) - 96) if "ァ" <= c <= "ン" else c for c in keyword])
        kata_keyword = "".join([chr(ord(c) + 96) if "ぁ" <= c <= "ん" else c for c in keyword])
        
        # ★ ここを「前方一致」に変更しました ( % を後ろだけに付ける )
        # これにより、「い」で検索すると「いす」「いちご」がヒットし、「だいこん」などはヒットしません
        query_obj = query_obj.filter(
            or_(
                TrashDictionary.name_ja.ilike(f"{keyword}%"),
                TrashDictionary.name_kana.ilike(f"{keyword}%"),
                TrashDictionary.name_kana.ilike(f"{hira_keyword}%"),
                TrashDictionary.name_kana.ilike(f"{kata_keyword}%")
            )
        )

    # 読みがなの50音順に並び替えて最大50件取得
    results = query_obj.order_by(TrashDictionary.name_kana.asc()).limit(50).all()
    
    data_list = []
    for item in results:
        target_name = getattr(item, f'name_{lang}', item.name_ja)
        
        # 「不明」対策: IDから直接名称を引く
        trash_type_name = "不明"
        if item.trash_type:
            trash_type_name = item.trash_type.name_ja
        elif item.trash_type_id:
            t_type = TrashType.query.get(item.trash_type_id)
            if t_type:
                trash_type_name = t_type.name_ja

        data_list.append({
            "id": item.id,
            "name": str(target_name or "名前なし"),
            "kana": str(item.name_kana or ""),
            "note": str(item.note_ja or "") if lang == 'ja' else str(getattr(item, 'note_en', item.note_ja) or ""),
            "fee": item.fee if item.fee is not None else 0,
            "trash_type_id": item.trash_type_id,
            "trash_type": trash_type_name
        })
        
    return jsonify(data_list)

# =========================================================
# 機能D: ゴミ箱の位置情報
# =========================================================
@app.route('/api/bins', methods=['GET'])
def get_bins():
    bins = TrashBin.query.all()
    result = []
    for b in bins:
        if b.latitude and b.longitude:
            result.append({"id": b.id, "name": b.name, "address": b.address, "type": b.bin_type, "lat": b.latitude, "lon": b.longitude})
    return jsonify(result)

# =========================================================
# 機能E: AIによる画像解析
# =========================================================
@app.route('/api/analyze_trash', methods=['POST'])
def analyze_trash():
    if not GEMINI_API_KEY: return jsonify({"error": "Gemini APIキー未設定"}), 500
    if 'image' not in request.files: return jsonify({"error": "画像なし"}), 400
    file = request.files['image']
    try:
        img = Image.open(file.stream)
        model = genai.GenerativeModel('gemini-1.5-flash')
        prompt = """ゴミ分別の専門家として解析しJSONで答えてください。{ "name": "名前", "type": "種別", "message": "アドバイス" }"""
        response = model.generate_content([prompt, img])
        response_text = response.text.replace('```json', '').replace('```', '').strip()
        return jsonify(json.loads(response_text))
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# =========================================================
# 機能F: 50音順リスト
# =========================================================
@app.route('/api/trash_dictionary', methods=['GET'])
def get_trash_dictionary():
    lang = request.args.get('lang', 'ja')
    items = TrashDictionary.query.order_by(TrashDictionary.name_kana.asc()).all()
    grouped_data = defaultdict(list)
    for item in items:
        first_char = item.name_kana[0] if item.name_kana else ""
        header = get_group_header(first_char)
        grouped_data[header].append(item.get_localized_data(lang))
    result = []
    headers_order = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "他"]
    for h in headers_order:
        if h in grouped_data:
            result.append({"header": h, "items": grouped_data[h]})
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)