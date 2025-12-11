from flask import Flask, jsonify, request
from flask_cors import CORS
# 作ったモデルたちを読み込む
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin, User
import google.generativeai as genai
import os

app = Flask(__name__)
app.json.ensure_ascii = False
CORS(app)

# トップページにアクセスしたときの表示
@app.route('/')
def home():
    return "API Server is Running! Access /api/areas to see data."

# データベースの設定
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///garbage_app.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

# --- ここから本物のAPI ---

# 1. エリア一覧取得 API
@app.route('/api/areas', methods=['GET'])
def get_areas():
    # DBから全エリアを取得
    areas = Area.query.all()
    
    # JSON形式（辞書リスト）に変換
    result = []
    for area in areas:
        result.append({
            "id": area.id,
            "name": area.name,
            "calendar_no": area.calendar_no
        })
    return jsonify(result)

# 2. ゴミ分別辞書検索 API
@app.route('/api/trash_dictionary', methods=['GET'])
def search_dictionary():
    keyword = request.args.get('keyword')
    
    if not keyword:
        return jsonify([])

    # DBから「品目名」か「かな」にキーワードを含むものを検索
    # User.name.contains(keyword) は SQLの LIKE '%keyword%' と同じ
    results = TrashDictionary.query.filter(
        (TrashDictionary.name.contains(keyword)) | 
        (TrashDictionary.name_kana.contains(keyword))
    ).all()
    
    response_data = []
    for item in results:
        response_data.append({
            "name": item.name,
            "note": item.note,
            # リレーションを使ってゴミ種別の詳細も一緒に返す
            "trash_type": {
                "name": item.trash_type.name_ja,
                "color": item.trash_type.color_code,
                "icon": item.trash_type.icon_name
            }
        })
        
    return jsonify(response_data)

# 3. スケジュール取得 API (日付対応版)
@app.route('/api/schedules', methods=['GET'])
def get_schedules():
    area_id = request.args.get('area_id')
    # ついでに「何月のデータが欲しいか」も指定できるようにするとベスト
    target_month = request.args.get('month') # 例: "2025-10"

    if not area_id:
        return jsonify({"error": "area_id is required"}), 400

    query = Schedule.query.filter_by(area_id=area_id)
    
    # 月指定があれば絞り込む（なければ全データ）
    # ※本番ではデータ量が多いので月指定必須にした方が良い
    
    schedules = query.all()
    
    result = []
    for s in schedules:
        result.append({
            "date": s.date.strftime('%Y-%m-%d'), # "2025-10-01"
            "day_of_week": s.date.weekday(),     # 曜日判定用
            "trash_type": {
                "name": s.trash_type.name_ja,
                "color": s.trash_type.color_code,
                "icon": s.trash_type.icon_name
            }
        })
    
    return jsonify(result)

# 4. AI画像解析 API (Gemini連携)
# ★ここにAPIキーを入れてください（テスト用）
GOOGLE_API_KEY = "ここに取得したGeminiのAPIキーを入れる"
genai.configure(api_key=GOOGLE_API_KEY)

@app.route('/api/analyze_image', methods=['POST'])
def analyze_image():
    if 'image' not in request.files:
        return jsonify({"error": "No image"}), 400
    
    file = request.files['image']
    image_data = file.read()

    try:
        model = genai.GenerativeModel('gemini-1.5-flash')
        prompt = """
        ゴミ収集カレンダーを解析し、以下のJSONのみ出力してください:
        {"burnable": ["月", "木"], "plastic": ["火"], "other": []}
        曜日は日本語、なければ空リスト。Markdown不要。
        """
        
        contents = [{"parts": [{"text": prompt}, {"inline_data": {"mime_type": "image/jpeg", "data": image_data}}]}]
        response = model.generate_content(contents)
        
        # 簡易的な整形（Markdown除去）
        clean_text = response.text.replace('```json', '').replace('```', '').strip()
        
        return jsonify({"status": "success", "data": clean_text})
        
    except Exception as e:
        # エラー時は空っぽのダミーを返してアプリを落とさない
        print(f"AI Error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5000)