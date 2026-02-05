from flask import Flask, jsonify, request, render_template, send_from_directory
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
# 1. 設定と準備 (Configuration)
# ------------------------------------------------------------------

load_dotenv()

app = Flask(__name__, static_folder='static_web')
app.json.ensure_ascii = False

app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or 'postgresql://student:password@localhost/banana_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

CORS(app)
db.init_app(app)

GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

# Geminiモデル確認（デバッグ用）
try:
    if GEMINI_API_KEY:
        client = genai.Client(api_key=GEMINI_API_KEY)
        # print("--- Available Models ---")
        # for m in client.models.list(config={"page_size": 10}):
        #     print(m.name)
except Exception as e:
    print(f"Warning: Could not list Gemini models. {e}")


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


# ------------------------------------------------------------------
# 2. ルート設定 (Routes)
# ------------------------------------------------------------------

@app.route('/')
def index():
    return "Banana Server is Running!"

# 機能A: カレンダー (変更なし)
@app.route('/api/schedules', methods=['GET'])
def get_schedules():
    year = request.args.get('year', type=int)
    month = request.args.get('month', type=int)
    area_id = request.args.get('area', type=int)

    if not year or not month or not area_id:
        return jsonify({"error": "year, month, and area are required"}), 400

    schedules = Schedule.query.filter_by(
        area_id=area_id,
        year=year,
        month=month
    ).all()

    result = []
    for s in schedules:
        # name_en属性があるか安全に確認
        type_en = getattr(s.trash_type, 'name_en', None)
        
        result.append({
            "date": s.date.strftime('%Y-%m-%d'),
            "type": s.trash_type.name,
            "type_en": type_en
        })
    return jsonify(result)

# 機能B: エリア (変更なし)
@app.route('/api/areas', methods=['GET'])
def get_areas():
    areas = Area.query.all()
    return jsonify([{"id": a.id, "name": a.name} for a in areas])

# 機能C: マップ (変更なし)
@app.route('/api/trash_bins', methods=['GET'])
def get_trash_bins():
    bins = TrashBin.query.all()
    return jsonify([{
        "id": b.id,
        "name": b.name,
        "lat": b.latitude,
        "lng": b.longitude,
        "type": b.bin_type,
        "address": b.address
    } for b in bins])

# =========================================================
# 機能D: 分別辞書リスト (修正版)
# =========================================================
@app.route('/api/trash_dictionary', methods=['GET'])
def get_trash_dictionary():
    lang = request.args.get('lang', 'ja')
    grouped_data = defaultdict(list)
    result = []

    # name_en カラムがモデルに存在するかチェック
    has_english = hasattr(TrashDictionary, 'name_en')

    if lang == 'en' and has_english:
        # --- 英語モードかつ英語カラムがある場合 ---
        try:
            items = TrashDictionary.query.all()
            # 英語名順にソート（ない場合は日本語名）
            items.sort(key=lambda x: (x.name_en if x.name_en else x.name).upper())
            
            for item in items:
                display_name = item.name_en if item.name_en else item.name
                first_char = display_name[0].upper() if display_name else "#"
                if not ('A' <= first_char <= 'Z'):
                    first_char = '#' 
                
                grouped_data[first_char].append(item.get_localized_data(lang))

            headers_order = sorted([k for k in grouped_data.keys() if k != '#'])
            if '#' in grouped_data:
                headers_order.append('#')
        except Exception as e:
            print(f"Dictionary Error (EN): {e}")
            # エラー時は空リストを返す
            return jsonify([])

    else:
        # --- 日本語モード または 英語カラムがない場合 ---
        try:
            items = TrashDictionary.query.order_by(TrashDictionary.name_kana.asc()).all()
            for item in items:
                first_char = item.name_kana[0] if item.name_kana else ""
                header = get_group_header(first_char)
                grouped_data[header].append(item.get_localized_data(lang))
            
            headers_order = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "他"]
        except Exception as e:
            print(f"Dictionary Error (JP): {e}")
            return jsonify([])

    for header in headers_order:
        if header in grouped_data:
            result.append({
                'header': header,
                'items': grouped_data[header]
            })

    return jsonify(result)


# =========================================================
# 機能E: 検索 (修正版: 日本語・英語両方検索可能)
# =========================================================
@app.route('/api/trash_search', methods=['GET'])
def trash_search():
    query = request.args.get('q', '')
    cat_id = request.args.get('cat_id')
    lang = request.args.get('lang', 'ja')

    try:
        base_query = TrashDictionary.query

        if cat_id:
            base_query = base_query.filter(TrashDictionary.trash_type_id == cat_id)

        if query:
            # 検索条件リスト
            conditions = [
                TrashDictionary.name.contains(query),       # 日本語名
                TrashDictionary.name_kana.contains(query),  # 読み仮名
            ]
            
            # name_en がモデルにある時だけ英語検索も追加
            if hasattr(TrashDictionary, 'name_en'):
                conditions.append(TrashDictionary.name_en.ilike(f'%{query}%'))
            
            base_query = base_query.filter(or_(*conditions))

        # ソート順
        if lang == 'en' and hasattr(TrashDictionary, 'name_en'):
            results = base_query.order_by(TrashDictionary.name_en.asc().nulls_last()).all()
        else:
            results = base_query.order_by(TrashDictionary.name_kana.asc()).all()

        return jsonify([item.get_localized_data(lang) for item in results])

    except Exception as e:
        print("SEARCH ERROR:", e)
        # エラー時は空リストを返す
        return jsonify([])


# 機能F: AI判定 (言語対応版)
@app.route('/api/predict_trash', methods=['POST'])
def predict_trash():
    if 'image' not in request.files:
        return jsonify({"error": "No image part"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    # ★ フロントエンドから言語コードを取得 (デフォルトは 'ja')
    user_lang = request.form.get('lang', 'ja')

    try:
        if not GEMINI_API_KEY:
            return jsonify({"error": "Server API Key not configured"}), 500

        img = Image.open(file.stream)

        # ★ 言語コードに対応する「AIへの指示言語名」を定義
        # ここで定義するだけで十分高速です（外部ファイルにする必要はありません）
        lang_map = {
            'ja': 'Japanese',
            'en': 'English',
            'zh': 'Simplified Chinese',
            'ko': 'Korean',
            'ru': 'Russian',
            'vi': 'Vietnamese',
            'id': 'Indonesian',
            # 必要に応じて他の言語を追加
        }

        # 指定された言語がない場合は 'Japanese' を使う
        target_language = lang_map.get(user_lang, 'Japanese')

        # ★ プロンプトの中に target_language を埋め込む
        prompt = f"""
        Analyze this image and identify the trash item.
        Return ONLY a JSON object with this exact format:
        {{
            "name": "Item Name ({target_language})",
            "type": "Burnable/Non-burnable/Recyclable/etc ({target_language})",
            "confidence": 0.95,
            "reason": "Reason for classification ({target_language})"
        }}
        """
        # ↑ ここで {target_language} の部分が 'English' や 'Vietnamese' に置き換わります。
        # JSONのキー ("name", "type") は英語のままにしておくのがプログラム的に安全です。
        # AIは「値」の部分だけを指定された言語で返してくれます。

        client = genai.Client(api_key=GEMINI_API_KEY)
        response = client.models.generate_content(
            model="gemini-flash-latest",
            contents=[img, prompt]
        )

        if not response.text:
            raise Exception("AIからの応答が空でした。")

        response_text = response.text.replace('```json', '').replace('```', '').strip()
        result_json = json.loads(response_text)
        return jsonify(result_json)

    except Exception as e:
        print(f"AI Error: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)