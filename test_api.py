import requests
import json

# 1. テストしたいAPIのURL
url = "http://127.0.0.1:5000/api/analyze_trash"

# 2. テストする画像ファイル名
image_file = "test_img/test5.jpg"

print(f"--- テスト開始: {image_file} を送信します ---")

try:
    # 画像を開いてAPIに送信する
    with open(image_file, 'rb') as f:
        # フロントエンドと同じ形式(files={'image': ...})で送る
        files = {'image': f}
        response = requests.post(url, files=files)

    # 3. 結果を表示
    print(f"ステータスコード: {response.status_code}")
    
    if response.status_code == 200:
        print("\n▼ AIからの返信 (成功):")
        # JSONをきれいに表示
        data = response.json()
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print("\n▼ エラー:")
        print(response.text)

except FileNotFoundError:
    print(f"エラー: {image_file} が見つかりません。同じフォルダに画像を置いてください。")
except Exception as e:
    print(f"通信エラー: {e}")