from flask import Flask, jsonify, request
from flask_cors import CORS
from models import db, Area, User, TrashType, Schedule, TrashDictionary, TrashBin
import os
import google.generativeai as genai
from PIL import Image
import io
import json
from dotenv import load_dotenv # ★追加: これで.envを読み込みます

# .envファイルを読み込む (これがエラーの原因でした！)
load_dotenv()

# アプリケーション設定
app = Flask(__name__)
app.json.ensure_ascii = False
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# CORSとDBの初期化
CORS(app)
db.init_app(app)

# Gemini APIの設定 (.envから読み込み)
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

# ----------------------------------------------------------------
# API ルート定義
# ----------------------------------------------------------------

@app.route('/')
def index():
    return jsonify({"message": "Banana API Server is running!"})

# (1) エリア一覧取得 API
@app.route('/api/areas', methods=['GET'])
def get_areas():
    try:
        areas = Area.query.all()
        return jsonify([area.to_dict() for area in areas])
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# (2) スケジュール取得 API
@app.route('/api/schedules', methods=['GET'])
def get_schedules():
    area_id = request.args.get('area_id')
    if not area_id:
        return jsonify({"error": "area_id is required"}), 400
    try:
        schedules = Schedule.query.filter_by(area_id=area_id).order_by(Schedule.date).all()
        return jsonify([s.to_dict() for s in schedules])
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# (3) 分別辞書 検索 API
@app.route('/api/trash_dictionary', methods=['GET'])
def search_trash_dictionary():
    keyword = request.args.get('q')
    try:
        if keyword:
            # 名前 または 備考(note) で検索できるように改良
            results = TrashDictionary.query.filter(
                (TrashDictionary.name.contains(keyword)) | 
                (TrashDictionary.note.contains(keyword))
            ).all()
        else:
            results = TrashDictionary.query.all()
        return jsonify([item.to_dict() for item in results])
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# (4) ゴミ箱マップ API (★以前の機能を復元・改良しました)
@app.route('/api/trash_bins', methods=['GET'])
def get_trash_bins():
    try:
        # URLパラメータから緯度経度を取得 (デフォルトは札幌駅周辺)
        lat = float(request.args.get('lat', 43.062))
        lon = float(request.args.get('lon', 141.354))
        radius = int(request.args.get('radius', 1000)) # 半径m (デフォルト1km)

        # 簡易的な範囲検索 (1度 ≒ 111km)
        delta = radius / 111000.0
        
        # 指定範囲内のゴミ箱を検索
        bins = TrashBin.query.filter(
            TrashBin.latitude.between(lat - delta, lat + delta),
            TrashBin.longitude.between(lon - delta, lon + delta)
        ).all()

        return jsonify([b.to_dict() for b in bins])
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# (5) ユーザー新規登録 API
@app.route('/api/users', methods=['POST'])
def create_user():
    data = request.json
    try:
        new_user = User(area_id=data.get('area_id'))
        db.session.add(new_user)
        db.session.commit()
        return jsonify({"message": "User created", "user": new_user.to_dict()}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

# (6) Gemini 画像解析 API
@app.route('/api/analyze_image', methods=['POST'])
def analyze_image():
    if not GEMINI_API_KEY:
        return jsonify({"error": "Server configuration error: Gemini API Key not found"}), 500

    # 画像ファイルのチェック
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    try:
        # 画像を読み込む
        img = Image.open(file.stream)

        # Geminiモデルの準備
        model = genai.GenerativeModel('gemini-1.5-flash')

        # プロンプト
        prompt = """
        あなたはゴミ分別の専門家です。
        この画像を分析し、以下の情報をJSON形式のみで出力してください。
        Markdown記法は不要です。
        
        {
            "name": "ゴミの名前",
            "type": "分別種別（燃えるゴミ、資源ゴミ、不燃ゴミなど）",
            "message": "捨て方のアドバイス"
        }
        """

        # AIを実行
        response = model.generate_content([prompt, img])
        
        # 結果のクリーニング
        text = response.text.replace('```json', '').replace('```', '').strip()
        
        return jsonify(json.loads(text))

    except Exception as e:
        print(f"Gemini Error: {e}")
        return jsonify({"error": "Analysis failed", "details": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)