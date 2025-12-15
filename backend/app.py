from flask import Flask, jsonify, request
from flask_cors import CORS
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin, User
import google.generativeai as genai
import os
import base64

app = Flask(__name__)
app.json.ensure_ascii = False
CORS(app)

# ---------------------------------------------------------
# 1. データベース設定 (PostgreSQLに変更)
# ---------------------------------------------------------
# 書式: postgresql://ユーザー名:パスワード@ホスト:ポート/DB名
# ※ご自身の環境に合わせて "password" の部分を変更してください
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:postgres@localhost:5432/garbage_app'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)

# ---------------------------------------------------------
# 2. Gemini API設定
# ---------------------------------------------------------
# 環境変数または直接キーを設定
GOOGLE_API_KEY = os.environ.get('GOOGLE_API_KEY')
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)

# ---------------------------------------------------------
# API エンドポイント実装
# ---------------------------------------------------------

@app.route('/')
def home():
    return "Banana API Server (PostgreSQL) is Running!"

# (1) エリア一覧取得 API
@app.route('/api/areas', methods=['GET'])
def get_areas():
    areas = Area.query.all()
    result = []
    for area in areas:
        result.append({
            "id": area.id,
            "name": area.name,
            "calendar_no": area.calendar_no
        })
    return jsonify(result)

# (2) スケジュール取得 API
@app.route('/api/schedules', methods=['GET'])
def get_schedules():
    area_id = request.args.get('area_id')
    if not area_id:
        return jsonify({"error": "area_id is required"}), 400

    # 本来は year, month でフィルタリングするが、今回は全件または直近を返す
    schedules = Schedule.query.filter_by(area_id=area_id).all()
    
    result = []
    for sch in schedules:
        trash_type = TrashType.query.get(sch.trash_type_id)
        result.append({
            "date": sch.date.isoformat(),
            "trash_type_id": sch.trash_type_id,
            "trash_name": trash_type.name_ja if trash_type else "不明",
            "color": trash_type.color_code if trash_type else "#000000",
            "icon": trash_type.icon_name if trash_type else "help"
        })
    return jsonify(result)

# (3) 辞書検索 API
@app.route('/api/trash_dictionary', methods=['GET'])
def search_dictionary():
    keyword = request.args.get('q', '')
    if not keyword:
        return jsonify([])

    # 部分一致検索 (名前 または 備考)
    results = TrashDictionary.query.filter(
        (TrashDictionary.name.contains(keyword)) | 
        (TrashDictionary.note.contains(keyword))
    ).all()
    
    data = []
    for r in results:
        t_type = TrashType.query.get(r.trash_type_id)
        data.append({
            "id": r.id,
            "name": r.name,
            "note": r.note,
            "trash_type_name": t_type.name_ja if t_type else "不明"
        })
    return jsonify(data)

# (4) AI画像解析 API
@app.route('/api/analyze_image', methods=['POST'])
def analyze_image():
    if not GOOGLE_API_KEY:
        return jsonify({"error": "Server API Key not set"}), 500
        
    try:
        req_data = request.get_json()
        image_data = req_data.get('image') # base64 string
        
        if not image_data:
            return jsonify({"error": "No image data"}), 400

        # プロンプトの作成
        prompt = """
        この画像を分析し、札幌市のゴミ分別ルールに基づいてゴミの種類を判定してください。
        回答は必ず以下のJSON形式のみで返してください。Markdown記法は不要です。
        {
            "result_id": (燃やせる=1, 燃やせない=2, 資源=8, プラ=9, 雑がみ=10, その他=99 から選択),
            "result_name": "ゴミ種別名",
            "confidence": "high/medium/low",
            "message": "短いアドバイス(例: 新聞紙に包んで出してください)"
        }
        """
        
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        # Base64をデコードせずにGeminiに渡す方法もあるが、辞書型で渡すのが一般的
        response = model.generate_content([
            {'mime_type': 'image/jpeg', 'data': image_data},
            prompt
        ])
        
        # Markdownの ```json ... ``` を除去
        clean_text = response.text.replace('```json', '').replace('```', '').strip()
        
        return clean_text, 200, {'Content-Type': 'application/json'}

    except Exception as e:
        print(f"AI Error: {e}")
        return jsonify({"error": str(e)}), 500

# (5) ゴミ箱マップ API (新規追加)
@app.route('/api/trash_bins', methods=['GET'])
def get_trash_bins():
    try:
        lat = float(request.args.get('lat', 43.062)) # デフォルト: 札幌中心部
        lon = float(request.args.get('lon', 141.354))
        radius = int(request.args.get('radius', 1000)) # 半径m

        # 簡易的な範囲検索 (本来はPostGISのST_DWithinを使うと正確)
        # 緯度経度 1度 ≒ 111km, 0.01度 ≒ 1.1km
        delta = radius / 111000.0
        
        bins = TrashBin.query.filter(
            TrashBin.latitude.between(lat - delta, lat + delta),
            TrashBin.longitude.between(lon - delta, lon + delta)
        ).all()

        result = []
        for b in bins:
            result.append({
                "id": b.id,
                "name": b.name,
                "latitude": b.latitude,
                "longitude": b.longitude,
                "bin_type": b.bin_type,
                "address": b.address
            })
        return jsonify(result)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)