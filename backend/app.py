from flask import Flask, jsonify, request, render_template
from flask_cors import CORS
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin
import os
import google.generativeai as genai
from PIL import Image
from dotenv import load_dotenv 

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
# student:password@localhost/banana_db の部分はご自身の環境に合わせてください
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or 'postgresql://student:password@localhost/banana_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# CORS (Cross-Origin Resource Sharing) の設定
# スマホアプリや別のWebサイトからこのサーバーにアクセスできるように許可します
CORS(app)

# データベース機能をアプリと連携させます
db.init_app(app)

# Gemini API (GoogleのAI) の設定
# 画像診断機能に使います
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)


# ------------------------------------------------------------------
# 2. APIの窓口（ルート）定義
# ------------------------------------------------------------------

# トップページアクセス確認用
# URL: http://localhost:5000/
#@app.route('/')
#def index():
#    return jsonify({"message": "Banana App API Server is running! (バナナアプリサーバー稼働中)"})


# =========================================================
# 機能A: 地域エリア一覧を取得する (多言語対応)
# URL例: http://localhost:5000/api/areas?lang=en
# =========================================================
@app.route('/api/areas', methods=['GET'])
def get_areas():
    # URLの「?lang=xx」の部分から言語コードを取得します（指定がなければ日本語 'ja'）
    lang = request.args.get('lang', 'ja')

    # データベースから全ての地域(Area)を取得します
    areas = Area.query.all()
    
    # 取得したデータをJSON形式（スマホが読みやすい形式）に変換リスト化します
    result = []
    for area in areas:
        data = {
            "id": area.id,
            # models.py で作った関数を使って、指定された言語の名前を取り出します
            "name": area.get_localized_name(lang), 
            "calendar_no": area.calendar_no
        }
        result.append(data)
        
    # 結果を返します
    return jsonify(result)


# =========================================================
# 機能B: 指定した地域のスケジュールを取得する
# URL例: http://localhost:5000/api/schedules?area_id=1
# =========================================================
@app.route('/api/schedules', methods=['GET'])
def get_schedules():
    # URLから「どの地域のスケジュールが欲しいか (area_id)」を取得します
    area_id = request.args.get('area_id')
    
    if not area_id:
        return jsonify({"error": "地域ID(area_id)を指定してください"}), 400

    # データベースから、その地域のスケジュールを検索します
    # ScheduleテーブルとTrashTypeテーブルを結合して、ゴミの色の情報なども一緒に取ります
    schedules = Schedule.query.filter_by(area_id=area_id).all()
    
    result = []
    for sch in schedules:
        # スケジュールIDからゴミの種類(TrashType)の詳細を取得
        trash_type = TrashType.query.get(sch.trash_type_id)
        
        # もしゴミ種別が見つかればリストに追加
        if trash_type:
            result.append({
                "date": sch.date.strftime('%Y-%m-%d'), # 日付を文字列に変換 (例: 2025-10-01)
                "trash_type": {
                    "id": trash_type.id,
                    "name": trash_type.name_ja, # とりあえず日本語名を返却 (ここも多言語化可能)
                    "color": trash_type.color_code,  # アプリのカレンダーで表示する色
                    "icon": trash_type.icon_name     # アイコン名
                }
            })
    
    # 日付順に並び替えます
    result.sort(key=lambda x: x['date'])
    
    return jsonify(result)


# =========================================================
# 機能C: ゴミ分別辞典を検索する (多言語対応)
# URL例: http://localhost:5000/api/trash_search?q=バナナ&lang=en
# =========================================================
@app.route('/api/trash_search', methods=['GET'])
def search_trash():
    # 検索キーワード(q)と言語(lang)を取得します
    keyword = request.args.get('q', '')
    lang = request.args.get('lang', 'ja')
    
    # キーワードが空っぽなら、空のリストを返して終了
    if not keyword:
        return jsonify([])

    # データベースのTrashDictionaryテーブルから、名前にキーワードを含むものを探します
    # ※現状は日本語名(name_ja)に対して検索しています
    results = TrashDictionary.query.filter(TrashDictionary.name_ja.contains(keyword)).all()
    
    data_list = []
    for item in results:
        # その国の言葉に変換してリストに追加
        # (models.py に get_localized_data がある前提です。なければ手動で取得)
        if hasattr(item, 'get_localized_data'):
             data_list.append(item.get_localized_data(lang))
        else:
            # メソッドがない場合の予備コード
            target_name = getattr(item, f'name_{lang}', item.name_ja)
            data_list.append({
                "id": item.id,
                "name": target_name,
                "note": item.note_ja,
                "fee": item.fee,
                "trash_type": item.trash_type.name_ja if item.trash_type else "不明"
            })
        
    return jsonify(data_list)


# =========================================================
# 機能D: ゴミ箱マップのデータを取得する
# URL例: http://localhost:5000/api/bins
# =========================================================
@app.route('/api/bins', methods=['GET'])
def get_bins():
    # データベースから全てのゴミ箱データを取得
    bins = TrashBin.query.all()
    
    result = []
    for b in bins:
        # 地図に表示するためには、緯度(latitude)と経度(longitude)が必須です
        # データがあるものだけをリストに追加します
        if b.latitude and b.longitude:
            result.append({
                "id": b.id,
                "name": b.name,      # 場所の名前
                "address": b.address,# 住所
                "type": b.bin_type,  # 回収品目
                "lat": b.latitude,   # 緯度
                "lon": b.longitude   # 経度
            })
            
    return jsonify(result)


# =========================================================
# 機能E: AIによるゴミ画像診断 (Gemini API)
# URL: http://localhost:5000/api/analyze_trash (POSTメソッド)
# =========================================================
@app.route('/api/analyze_trash', methods=['POST'])
def analyze_trash():
    # 1. APIキーの設定チェック
    if not GEMINI_API_KEY:
        return jsonify({"error": "サーバーエラー: Gemini APIキーが設定されていません"}), 500

    # 2. スマホから画像ファイルが送られてきているかチェック
    if 'image' not in request.files:
        return jsonify({"error": "画像ファイルが見つかりません"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "ファイルが選択されていません"}), 400

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
        Markdownの記法（```jsonなど）は含めないでください。

        出力フォーマット:
        {
            "name": "ゴミの名前（例: ペットボトル、乾電池）",
            "type": "ゴミの種別（例: 燃えるゴミ、資源ゴミ、不燃ゴミ、不明）",
            "message": "分別のアドバイスを一言（例: ラベルとキャップを外して洗ってください）"
        }
        """

        # 6. AIに画像と命令を送って、答えを待ちます
        response = model.generate_content([prompt, img])
        
        # 7. AIの答え(文字列)を取り出し、JSONとして読み込みます
        response_text = response.text.replace('```json', '').replace('```', '').strip()
        result_json = json.loads(response_text)

        # 8. スマホアプリに結果を返します
        return jsonify(result_json)

    except Exception as e:
        # 何かエラーが起きたらログに出して、エラーメッセージを返します
        print(f"AI診断エラー: {e}")
        return jsonify({"error": f"AI診断に失敗しました: {str(e)}"}), 500

# --- 追加ここから ---
@app.route('/')
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
