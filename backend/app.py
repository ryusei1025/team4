from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin
import os
from google import genai
from PIL import Image
from dotenv import load_dotenv
import json
from collections import defaultdict
from sqlalchemy import or_

# =========================================================
# 初期設定
# =========================================================
load_dotenv()

app = Flask(__name__)
app.json.ensure_ascii = False

app.config['SQLALCHEMY_DATABASE_URI'] = (
    os.environ.get('DATABASE_URL')
    or 'postgresql://student:password@localhost/banana_db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

CORS(app)
db.init_app(app)

GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

# =========================================================
# ヘルパー
# =========================================================
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

# =========================================================
# API
# =========================================================
@app.route('/api/health')
def health():
    return jsonify({"status": "ok"})

@app.route('/api/bins')
def get_bins():
    bins = TrashBin.query.all()
    return jsonify([
        {
            "id": b.id,
            "name": b.name,
            "address": b.address,
            "type": b.bin_type,
            "lat": b.latitude,
            "lon": b.longitude
        }
        for b in bins if b.latitude and b.longitude
    ])

@app.route('/api/areas')
def get_areas():
    lang = request.args.get('lang', 'ja')
    return jsonify([
        {
            "id": a.id,
            "name": a.get_localized_name(lang),
            "calendar_no": a.calendar_no
        } for a in Area.query.all()
    ])

@app.route('/api/schedules')
def get_schedules():
    area_id = request.args.get('area_id')
    if not area_id:
        return jsonify({"error": "area_id required"}), 400

    schedules = Schedule.query.filter_by(area_id=area_id).all()
    result = []

    for s in schedules:
        t = TrashType.query.get(s.trash_type_id)
        if t:
            result.append({
                "date": s.date.strftime('%Y-%m-%d'),
                "trash_type": {
                    "id": t.id,
                    "name": t.name_ja,
                    "color": t.color_code,
                    "icon": t.icon_name
                }
            })

    return jsonify(sorted(result, key=lambda x: x['date']))

@app.route('/api/trash_search')
def search_trash():
    keyword = request.args.get('q', '').strip()
    query = TrashDictionary.query

    if keyword:
        hira = "".join(chr(ord(c)-96) if "ァ" <= c <= "ン" else c for c in keyword)
        kata = "".join(chr(ord(c)+96) if "ぁ" <= c <= "ん" else c for c in keyword)

        query = query.filter(or_(
            TrashDictionary.name_ja.ilike(f"{keyword}%"),
            TrashDictionary.name_kana.ilike(f"{keyword}%"),
            TrashDictionary.name_kana.ilike(f"{hira}%"),
            TrashDictionary.name_kana.ilike(f"{kata}%")
        ))

    items = query.order_by(TrashDictionary.name_kana).limit(50).all()
    return jsonify([
        {
            "id": i.id,
            "name": i.name_ja,
            "kana": i.name_kana,
            "trash_type": i.trash_type.name_ja if i.trash_type else "不明"
        } for i in items
    ])

@app.route('/api/analyze_trash', methods=['POST'])
def analyze_trash():
    if 'image' not in request.files:
        return jsonify({"error": "image required"}), 400

    img = Image.open(request.files['image'].stream)
    client = genai.Client(api_key=GEMINI_API_KEY)

    response = client.models.generate_content(
        model='gemini-flash-latest',
        contents=[img, "ゴミ分別をJSONで返してください"]
    )

    return jsonify(json.loads(response.text.strip("```json```")))

# =========================================================
# Flutter Web（必要な場合のみ）
# =========================================================
@app.route('/web/<path:path>')
def web_static(path):
    return send_from_directory('static_web', path)

@app.route('/web')
def web_index():
    return send_from_directory('static_web', 'index.html')

# =========================================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
