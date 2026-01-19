from flask import Flask, jsonify, request, render_template
from flask_cors import CORS
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin
import os
import google.generativeai as genai
from PIL import Image
from dotenv import load_dotenv 
import json # AI診断の結果を処理するために必要

# ------------------------------------------------------------------
# 1. 設定と準備 (Configuration)
# ------------------------------------------------------------------

# .env ファイルから秘密の鍵（APIキーなど）を読み込みます
load_dotenv()

# Flaskアプリ（サーバー本体）を作成します
app = Flask(__name__)

# 日本語の文字化けを防ぐための設定です
app.json.ensure_ascii = False

# データベースの接続先を設定します (PostgreSQLに接続)
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or 'postgresql://student:password@localhost/banana_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# CORS (Cross-Origin Resource Sharing) の設定
# スマホアプリや別のWebサイトからこのサーバーにアクセスできるように許可します
CORS(app)

# データベース機能をアプリと連携させます
db.init_app(app)

# Gemini API (GoogleのAI) の設定
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)


# ------------------------------------------------------------------
# 2. APIの窓口（ルート）定義
# ------------------------------------------------------------------

# トップページアクセス確認用
# URL: 'https://50.17.227.109.nip.io'
@app.route('/')
def index():
    return jsonify({"message": "Banana App API Server is running! (バナナアプリサーバー稼働中)"})


# --- 機能A: 地域エリア一覧を取得 ---
@app.route('/api/areas', methods=['GET'])
def get_areas():
    lang = request.args.get('lang', 'ja')
    areas = Area.query.all()
    result = []
    for area in areas:
        data = {
            "id": area.id,
            "name": area.get_localized_name(lang), 
            "calendar_no": area.calendar_no
        }
        result.append(data)
    return jsonify(result)

# --- 機能B: 指定したエリアのゴミ出しスケジュールを取得 ---
@app.route('/api/schedules', methods=['GET'])
def get_schedules():
    area_id = request.args.get('area_id')
    if not area_id:
        return jsonify({"error": "area_idを指定してください"}), 400

    schedules = Schedule.query.filter_by(area_id=area_id).all()
    result = []
    for sch in schedules:
        trash_type = TrashType.query.get(sch.trash_type_id)
        if trash_type:
            result.append({
                "date": sch.date.strftime('%Y-%m-%d'),
                "trash_type": {
                    "id": trash_type.id,
                    "name": trash_type.name_ja,
                    "color": trash_type.color_code,
                    "icon": trash_type.icon_name
                }
            })
    result.sort(key=lambda x: x['date']) # 日付順に並び替え
    return jsonify(result)


# =========================================================
# 機能C: ゴミ分別辞典を検索する (名前検索 ＆ カテゴリー絞り込み)
# =========================================================
@app.route('/api/trash_search', methods=['GET'])
def search_trash():
    # 1. パラメータの受け取り
    keyword = request.args.get('q', '')       # 検索窓に入力された文字
    lang = request.args.get('lang', 'ja')     # 言語(ja/en)
    cat_id = request.args.get('cat_id', '')   # カテゴリー一覧用ID
    
    # クエリ（検索条件）を組み立てる準備
    query_obj = TrashDictionary.query

    # --- サーバー側でのデバッグログ (ターミナルに表示) ---
    print(f"\n[検索] cat_id={cat_id}, keyword={keyword}")

    # 2. 検索条件の追加
    # カテゴリーID(cat_id)があれば絞り込み
    if cat_id:
        try:
            target_id = int(cat_id)
            query_obj = query_obj.filter_by(trash_type_id=target_id)
        except ValueError:
            pass

    # キーワード(keyword)があれば名前で検索
    if keyword:
        query_obj = query_obj.filter(TrashDictionary.name_ja.contains(keyword))

    # 条件が全くない場合は何も返さない
    if not keyword and not cat_id:
        return jsonify([])

    # データベースから検索実行
    results = query_obj.all()
    print(f"結果: {len(results)} 件ヒットしました")
    
    # 3. レスポンス用データの組み立て
    data_list = []
    for item in results:
        # 言語に合わせて名前を取得
        target_name = getattr(item, f'name_{lang}', item.name_ja)
        
        # ★ ここが重要：Flutter側が期待する「キー名」で辞書を作成します
        data_list.append({
            "id": item.id,
            "name": target_name,
            "note": item.note_ja if lang == 'ja' else getattr(item, 'note_en', item.note_ja),
            "fee": item.fee,
            "trash_type_id": item.trash_type_id,
            # ここを "trash_type" に戻しました（前回は trash_type_name にしてしまっていました）
            "trash_type": item.trash_type.name_ja if item.trash_type else "不明"
        })
        
    return jsonify(data_list)


# --- 機能D: ゴミ箱マップの場所データを取得 ---
@app.route('/api/bins', methods=['GET'])
def get_bins():
    bins = TrashBin.query.all()
    result = []
    for b in bins:
        if b.latitude and b.longitude:
            result.append({
                "id": b.id, "name": b.name, "address": b.address,
                "type": b.bin_type, "lat": b.latitude, "lon": b.longitude
            })
    return jsonify(result)

# --- 機能E: AIによるゴミ画像診断 (Gemini) ---
@app.route('/api/analyze_trash', methods=['POST'])
def analyze_trash():
    if not GEMINI_API_KEY:
        return jsonify({"error": "Gemini APIキー未設定"}), 500
    if 'image' not in request.files:
        return jsonify({"error": "画像がアップロードされていません"}), 400
    
    file = request.files['image']
    try:
        # 3. 画像を開く (Pillowライブラリを使用)
        img = Image.open(file.stream)

        # 4. Geminiモデルの準備 (高速な flash モデルを使用)
        model = genai.GenerativeModel('gemini-flash-latest')

        # 5. AIへの命令文 (プロンプト)
        # ここを変えるとAIのキャラや回答形式が変わります
        prompt = """
        あなたは日本のゴミ分別の専門家です。
        アップロードされた画像を解析し、以下の情報をJSON形式のみで出力してください。
        Markdown(```jsonなど)は含めないでください。
        {
            "name": "ゴミの名前",
            "type": "ゴミの種別",
            "message": "分別のアドバイスを一言"
        }
        """
        response = model.generate_content([prompt, img])
        
        # AIの回答をJSONとしてパース
        response_text = response.text.replace('```json', '').replace('```', '').strip()
        result_json = json.loads(response_text)
        
        return jsonify(result_json)
    except Exception as e:
        return jsonify({"error": f"AI診断失敗: {str(e)}"}), 500

# --- geminiテスト用 ---
@app.route('/api/gemini_test', methods=['POST'])
def camera_page():
    # さっき作った upload.html を表示する
    return render_template('upload.html')
# --- 追加ここまで ---

# ------------------------------------------------------------------
# 3. サーバーの起動
# ------------------------------------------------------------------
if __name__ == '__main__':
    # import json が必要なのでここで追加確認
    import json
    
    # デバッグモードONでサーバーを起動 (コードを変えると自動で再起動してくれます)
    app.run(host='0.0.0.0', port=5000, debug=True)
