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
            results = TrashDictionary.query.filter(
                (TrashDictionary.name.contains(keyword)) | 
                (TrashDictionary.note.contains(keyword))
            ).all()
        else:
            results = TrashDictionary.query.all()
        
        # to_dict() を使わずに、ここで直接辞書を作る（確実な方法）
        return jsonify([{
            "id": item.id,
            "name": item.name,
            "note": item.note,
            "trash_type_name": "燃えるゴミ"  # ★ここが Flutter側で必要です
        } for item in results])

    except Exception as e:
        print(f"Error: {e}") # ターミナルにエラー内容を表示
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
    # 1. APIキーの確認
    if not GEMINI_API_KEY:
        return jsonify({"error": "Server configuration error: Gemini API Key not found"}), 500

    # 2. 画像ファイルが送られてきているかチェック
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    try:
        # 3. 画像を読み込む (Pillowを使用)
        img = Image.open(file.stream)

        # 4. Geminiモデルの準備 (高速な flash モデルを使用)
        model = genai.GenerativeModel('gemini-flash-latest')

        # 5. AIへの命令 (プロンプト)
        # ここを変えるとAIのキャラが変わります！
        prompt = """
        あなたは日本のゴミ分別の専門家です。
        アップロードされた画像を解析し、以下の情報をJSON形式のみで出力してください。
        Markdownの記法（```jsonなど）は含めないでください。

        出力フォーマット:
        {
            "name": "ゴミの名前（例: ペットボトル、乾電池）",
            "type": "ゴミの種別（例: 燃えるゴミ、資源ゴミ、不燃ゴミ、不明）",
            "message": "分別のアドバイスを一言（例: ラベルとキャップを外して洗ってください）"
        }
        """

        # 6. AIを実行
        response = model.generate_content([prompt, img])
        
        # 7. 結果のクリーニング (Markdown記法を削除してJSONにする)
        clean_text = response.text.replace('```json', '').replace('```', '').strip()
        result_json = json.loads(clean_text)

        return jsonify(result_json)

    except Exception as e:
        print(f"Gemini Error: {e}")
        return jsonify({"error": "Analysis failed", "details": str(e)}), 500
@app.route('/api/getdictionary', methods=['GET'])
def getdictionary():
    try:
        # 1. TrashDictionary と TrashType を ID で紐付けて一緒に取得する
        items = db.session.query(TrashDictionary, TrashType).join(
            TrashType, TrashDictionary.trash_type_id == TrashType.id
        ).all()
        
        # 2. データをリスト形式に変換
        results = []
        for dictionary, t_type in items:
            results.append({
                'id': dictionary.id,
                'name': dictionary.name, # ゴミの名前（例：ランドセル）
                'note': dictionary.note,
                'fee': dictionary.fee,
                # 2. ここで Flutter が探している 'trash_type_name' を入れる
                'trash_type_name': t_type.name # ゴミの種類（例：燃やせるごみ）
            })
        
        # 3. JSONとしてレスポンスを返す
        return jsonify(results)
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)