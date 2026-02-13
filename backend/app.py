import io
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from models import db, Schedule, Area, TrashBin, TrashDictionary
import os
from google import genai
from PIL import Image
from dotenv import load_dotenv
import json
import datetime
import random
import data_loader
from collections import defaultdict
from sqlalchemy import or_
import time



# ------------------------------------------------------------------
# 1. 設定と準備
# ------------------------------------------------------------------

load_dotenv()

app = Flask(__name__)
app.json.ensure_ascii = False

# データベース設定
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or 'postgresql://student:password@localhost/banana_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

CORS(app)
db.init_app(app)

GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')


def get_group_header(char):
    """
    読み仮名の頭文字から「あ行・か行...」のグループ名を返す関数
    """
    if not char: return "他"
    c = char[0]

    # カタカナ → ひらがな変換
    if 'ァ' <= c <= 'ヶ':
        c = chr(ord(c) - 0x60)

    if c == 'ゔ': return 'あ'

    if c < 'ぁ': return "他"
    if c < 'か': return "あ"
    if c < 'さ': return "か"
    if c < 'た': return "さ"
    if c < 'な': return "た"
    if c < 'は': return "な"
    if c < 'ま': return "は"
    if c < 'や': return "ま"
    if c < 'ら': return "や"
    if c < 'わ': return "ら"
    if c <= 'ん': return "わ"

    return "他"


def get_translated_value(item, field_base, lang):
    """モデルのフィールドから言語に応じた値を取得するヘルパー関数"""
    target_col = f"{field_base}_{lang}"
    if lang == 'zh': target_col = f"{field_base}_zh_cn"
    
    val = getattr(item, target_col, None)
    if val and str(val).strip():
        return val
        
    fallback_col = f"{field_base}_ja"
    return getattr(item, fallback_col, '')

# サーバー起動時にCSVを読み込ませる
with app.app_context():
    data_loader.load_data()

# ------------------------------------------------------------------
# ヘルパー関数 (ロジック系)
# ------------------------------------------------------------------

def get_next_collection_date(schedules):
    """スケジュールリストから直近の日付を取得"""
    if not schedules: return None
    today = datetime.date.today()
    future_dates = []
    for s in schedules:
        try:
            check_date = s.date
            if isinstance(check_date, str):
                check_date = datetime.datetime.strptime(check_date, '%Y-%m-%d').date()
            if check_date >= today:
                future_dates.append(check_date)
        except:
            continue
    if not future_dates: return None
    return min(future_dates).strftime("%Y-%m-%d")


# ------------------------------------------------------------------
# 2. ルート設定 (Routes)
# ------------------------------------------------------------------

@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory(app.static_folder, path)

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
    # 簡易的に日本語名を返す（必要に応じて多言語化）
    return jsonify([{"id": a.id, "name": a.name_ja} for a in areas])

@app.route('/api/trash_bins', methods=['GET']) # URLも確認！
def get_trash_bins():
    bins = TrashBin.query.all()
    results = []
    for b in bins:
        # 緯度経度がないデータは除外する安全策
        if b.latitude is None or b.longitude is None:
            continue
            
        results.append({
            "id": b.id,
            "name": b.name,
            "lat": b.latitude,
            "lon": b.longitude,
            "type": b.bin_type,
            "address": b.address
        })
    return jsonify(results)

# 機能D: 分別辞書
@app.route('/api/trash_dictionary', methods=['GET'])
def get_trash_dictionary():
    lang = request.args.get('lang', 'ja')
    items = TrashDictionary.query.order_by(TrashDictionary.name_kana.asc()).all()
    grouped_data = defaultdict(list)

    for item in items:
        name_translated = get_translated_value(item, 'name', lang)
        note_translated = get_translated_value(item, 'note', lang)

        if not name_translated:
            continue

        if lang == 'ja':
            yomi = item.name_kana if item.name_kana else name_translated
            header = get_group_header(yomi)
        else:
            first_char = name_translated[0].upper()
            header = first_char if 'A' <= first_char <= 'Z' else '#'

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

    result = []
    sorted_headers = sorted(grouped_data.keys())

    if lang == 'ja':
        preferred_order = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "他"]
        sorted_keys = [h for h in preferred_order if h in grouped_data]
        for k in sorted_headers:
            if k not in sorted_keys:
                sorted_keys.append(k)
    else:
        sorted_keys = sorted_headers

    for header in sorted_keys:
        items_list = grouped_data[header]
        if lang != 'ja':
            items_list.sort(key=lambda x: x['name'].upper())
        result.append({'header': header, 'items': items_list})

    return jsonify(result)


# 機能E: 検索 (スケジュール表示対応版)
@app.route('/api/trash_search', methods=['GET'])
def trash_search():
    query_str = request.args.get('q', '').strip()
    cat_id = request.args.get('cat_id')
    lang = request.args.get('lang', 'ja')

    base_query = TrashDictionary.query

    if cat_id:
        base_query = base_query.filter(
            TrashDictionary.trash_type_id == cat_id
        )

    if query_str:
        search_term = f"{query_str}%"   # ★前方一致

        filters = []

        if hasattr(TrashDictionary, 'name_ja'):
            filters.append(TrashDictionary.name_ja.ilike(search_term))

        if hasattr(TrashDictionary, 'name_kana'):
            filters.append(TrashDictionary.name_kana.ilike(search_term))

        target_col = f"name_{lang}"
        if lang == 'zh':
            target_col = "name_zh_cn"

        if hasattr(TrashDictionary, target_col):
            filters.append(getattr(TrashDictionary, target_col).ilike(search_term))

        if filters:
            base_query = base_query.filter(or_(*filters))

    items = base_query.order_by(
        TrashDictionary.name_kana.asc()
    ).limit(50).all()

    result = []

    for item in items:
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

    if lang != 'ja':
        result.sort(key=lambda x: x['name'].upper())

    return jsonify(result)



# 機能F: AI判定 (モデル切り替え & エラーハンドリング強化版)
@app.route('/api/predict_trash', methods=['POST'])
def predict_trash():
    if 'image' not in request.files:
        return jsonify({"error": "No image part"}), 400
    
    file = request.files['image']
    area_id = request.form.get('area_id')
    user_lang = request.form.get('lang', 'ja')
    trash_type_map = data_loader.get_trash_type_map()

    try:
        img = Image.open(file.stream)
    except Exception as e:
        return jsonify({"error": "Invalid image file"}), 400

    # ---------------------------------------------------------
    # 2. Gemini AI による解析 (粘り強いリトライ版)
    # ---------------------------------------------------------
    
    # ★修正: 成功実績のある "latest" 系だけを使う
    models_to_try = ["gemini-flash-latest", "gemini-flash-lite-latest", "gemini-pro-latest"]
    
    ai_result = {}
    success_model = None
    last_error = None
    
    lang_map = { 'ja': 'Japanese', 'en': 'English', 'zh': 'Simplified Chinese', 'ko': 'Korean', 'vi': 'Vietnamese' }
    target_language = lang_map.get(user_lang, 'Japanese')

    prompt = f"""
    Analyze this image and identify the trash item.
    Task 1: Identify the object name specifically.
    Task 2: Classify into: 1.Burnable, 2.Non-burnable, 3.Bottles/Cans/PET, 4.Plastic Containers, 5.Mixed Paper, 6.Branches/Leaves.
    Task 3: Reason.
    Return ONLY JSON:
    {{ "identified_name_ja": "...", "identified_name_en": "...", "ai_type_id": "1-6", "ai_type_name": "...", "ai_reason": "..." }}
    """

    client = genai.Client(api_key=GEMINI_API_KEY)

    for model_name in models_to_try:
        # 各モデルで最大2回トライする (503対策)
        for attempt in range(2):
            try:
                print(f"DEBUG: Trying AI Model -> {model_name} (Attempt {attempt+1})")
                response = client.models.generate_content(
                    model=model_name,
                    contents=[img, prompt]
                )
                response_text = response.text.replace('```json', '').replace('```', '').strip()
                ai_result = json.loads(response_text)
                
                success_model = model_name
                break # 成功！リトライループを抜ける
            
            except Exception as e:
                error_msg = str(e)
                print(f"WARNING: {model_name} failed: {error_msg}")
                last_error = e
                
                # 503 (混雑) の場合のみ、少し待って再トライ
                if "503" in error_msg or "UNAVAILABLE" in error_msg:
                    time.sleep(2) # 2秒待つ
                    continue 
                else:
                    break # その他のエラー(429等)なら、このモデルは諦めて次のモデルへ
        
        if success_model:
            break # モデルループを抜ける

    # 全滅した場合
    if success_model is None:
        print(f"AI All Models Failed: {last_error}")
        return jsonify({
            "error": "AI_LIMIT_OR_ERROR",
            "message": str(last_error)
        }), 503

    # ---------------------------------------------------------
    # 3. 結果の整形 (辞書マッチング)
    # ---------------------------------------------------------
    final_name = ""
    final_type_id = 1
    final_type_name = ""
    final_reason = ""
    is_dictionary_match = False

    # 辞書検索
    dict_match = data_loader.find_in_dictionary(ai_result.get('identified_name_ja'))
    if not dict_match:
        dict_match = data_loader.find_in_dictionary(ai_result.get('identified_name_en'))

    if dict_match:
        # 辞書ヒット
        is_dictionary_match = True
        name_col = f"name_{user_lang}" if user_lang != 'zh' else 'name_zh_cn'
        final_name = dict_match.get(name_col) or dict_match.get('name_en')
        trash_str = dict_match.get('trash_type_str', '')
        final_type_name = trash_str
        
        # マップからIDへ
        for key, val in trash_type_map.items():
            if key in trash_str:
                final_type_id = val
                break
        
        note_col = 'note_ja' if user_lang == 'ja' else 'note_en'
        final_reason = dict_match.get(note_col, "")

    else:
        # AI結果
        is_dictionary_match = False
        final_name = ai_result.get(f'identified_name_{user_lang}') or ai_result.get('identified_name_en')
        final_type_id = int(ai_result.get('ai_type_id', 1))
        final_type_name = ai_result.get('ai_type_name')
        final_reason = ai_result.get('ai_reason')

    # スケジュール計算
    schedule_date = None
    if area_id and final_type_id:
        try:
            area_id_int = int(area_id)
            schedules = Schedule.query.filter_by(
                area_id=area_id_int, 
                trash_type_id=final_type_id
            ).all()
            if schedules:
                schedule_date = get_next_collection_date(schedules)
        except:
            pass

    return jsonify({
        "name": final_name,
        "type_id": final_type_id,
        "type": final_type_name, 
        "reason": final_reason,
        "confidence": 0.99 if is_dictionary_match else 0.85,
        "collection_schedule": schedule_date,
        "is_dictionary_match": is_dictionary_match,
        "model_used": success_model
    })


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
