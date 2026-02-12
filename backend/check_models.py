import os
from dotenv import load_dotenv
from google import genai # app.py と同じ新しいライブラリを使用

# .envファイルを読み込む
load_dotenv()

API_KEY = os.environ.get('GEMINI_API_KEY')

print("--------------------------------------------------")
if not API_KEY:
    print("❌ エラー: APIキーが見つかりません。.envファイルを確認してください。")
    exit()
else:
    print(f"✅ APIキーを読み込みました: {API_KEY[:5]}...****")

print("▼ Googleサーバーに問い合わせ中...")

try:
    client = genai.Client(api_key=API_KEY)
    
    # モデル一覧を取得
    pager = client.models.list()
    
    print("\n▼ あなたのAPIキーで使用可能なGeminiモデル一覧:")
    print("--------------------------------------------------")
    
    count = 0
    found_flash = False
    
    for model in pager:
        # "gemini" という名前が含まれるモデルだけを表示して見やすくする
        if "gemini" in model.name.lower():
            print(f"  - {model.name}")
            count += 1
            
            # 1.5-flash系が見つかったかチェック
            if "gemini-1.5-flash" in model.name:
                found_flash = True

    print("--------------------------------------------------")
    print(f"合計 {count} 個のGemini系モデルが見つかりました。")
    
    if found_flash:
        print("\n✅ 'gemini-1.5-flash' を含むモデルが見つかりました！")
        print("リストにある正確な名前（例: gemini-1.5-flash-002 等）を app.py にコピーしてください。")
    else:
        print("\n⚠️ 'gemini-1.5-flash' が見つかりませんでした。")
        print("リストに表示されているモデル名（例: gemini-pro 等）を app.py に使ってください。")

except Exception as e:
    print(f"\n❌ 通信エラーが発生しました:\n{e}")
    print("\n考えられる原因:")
    print("1. インターネットに繋がっていない")
    print("2. APIキーが無効になっている")
    print("3. ライブラリが古い (pip install --upgrade google-genai を試してください)")