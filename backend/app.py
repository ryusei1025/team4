from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)

# ★重要：スマホ(Flutter)からのアクセスを許可する設定
CORS(app)

# 日本語が文字化けしないようにする設定
app.json.ensure_ascii = False

# 動作確認用のURL（ルート）
@app.route('/')
def index():
    return jsonify({
        "message": "成功！Flaskサーバーが動いています",
        "status": "success"
    })

if __name__ == '__main__':
    # スマホ実機からつなぐ場合、host='0.0.0.0'が必要になることが多いですが
    # まずは開発用にデフォルトで起動します
    app.run(debug=True)