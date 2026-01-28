from flask import Flask, jsonify, request, render_template, send_from_directory
from flask_cors import CORS
from models import db, Area, TrashType, Schedule, TrashDictionary, TrashBin
import os
from google import genai
from PIL import Image
from dotenv import load_dotenv 
import json # AI診断の結果を処理するために必要
from collections import defaultdict # ★グループ化のために追加
from sqlalchemy import or_ # ★ひらがな・カタカナ検索のために追加

# ------------------------------------------------------------------
# 1. 設定と準備 (Configuration)
# ------------------------------------------------------------------

load_dotenv()

# Flaskアプリ（サーバー本体）を作成します
app = Flask(__name__, static_folder='static_web')

# 日本語の文字化けを防ぐための設定です
app.json.ensure_ascii = False

# データベースの接続先を設定します (PostgreSQLに接続)
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL') or 'postgresql://student:password@localhost/banana_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

CORS(app)
db.init_app(app)

# Gemini API の設定
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

# =========================================================
# ★追加コード: 起動時に「使えるモデル一覧」を表示する
# =========================================================
try:
    if GEMINI_API_KEY:
        print("\n======== 【デバッグ】利用可能なモデル一覧 ========")
        debug_client = genai.Client(api_key=GEMINI_API_KEY)
        for m in debug_client.models.list():
            # "generateContent" (文章生成) に対応しているモデルだけ表示
            if "generateContent" in (m.supported_actions or []):
                # モデル名の "models/" を除いて表示
                print(f"・ {m.name.replace('models/', '')}")
        print("================================================\n")
except Exception as e:
    print(f"モデル一覧の取得に失敗しました: {e}")
# =========================================================

# ルートURL（/）にアクセスしたら、Flutterの画面を返す
@app.route('/')
def serve_index():
    return send_from_directory(app.static_folder, 'index.html')

# その他のファイル（JS, CSS, 画像など）を返す
@app.route('/<path:path>')
def serve_static_files(path):
    file_path = os.path.join(app.static_folder, path)
    if os.path.exists(file_path):
        return send_from_directory(app.static_folder, path)
    # ファイルがない場合はindex.htmlを返す（Flutterの画面遷移用）
    return send_from_directory(app.static_folder, 'index.html')

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
# 機能E: 画像診断（Gemini API）
# =========================================================
# ★重要: URLをログに合わせて '/api/analyze_trash' にし、POSTを許可します
@app.route('/api/analyze_trash', methods=['POST']) 
def analyze_trash():
    # 画像ファイルが送られてきているかチェック
    if 'image' not in request.files:
        return jsonify({"error": "画像なし"}), 400

    file = request.files['image']

    try:
        # 画像を開く
        img = Image.open(file.stream)

        # ---------------------------------------------------------
        # 新しい google-genai ライブラリの書き方
        # ---------------------------------------------------------
        
        # 1. クライアントを作成
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        # 2. プロンプトの準備
        prompt = """
        ゴミ分別の専門家として解析してください。
        以下のJSONフォーマットのみで返答してください。余計な文章は不要です。
        { 
            "name": "ゴミの名前", 
            "type": "ゴミの種別(燃やせるゴミ/燃やせないゴミ/資源ごみ/など)", 
            "message": "分別のアドバイス" 
        }
        """

        # 3. AIにリクエストを送る
        response = client.models.generate_content(
            model='gemini-flash-latest',
            contents=[img, prompt]
        )

        if not response.text:
            raise Exception("AIからの応答が空でした。")

        response_text = response.text.replace('```json', '').replace('```', '').strip()
        result_json = json.loads(response_text)
        
        return jsonify(result_json)

    except Exception as e:
        print(f"============== エラー発生 ==============")
        print(e)
        import traceback
        traceback.print_exc()
        print(f"========================================")
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