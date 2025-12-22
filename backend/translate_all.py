import csv
import time
import os
import google.generativeai as genai
from dotenv import load_dotenv

# .env から APIキーを読み込む
load_dotenv()
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

if not GEMINI_API_KEY:
    print("エラー: .envファイルに GEMINI_API_KEY が設定されていません。")
    exit()

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-flash-latest')

# 入力ファイルと出力ファイル
INPUT_FILE = 'dataset/trash_dictionary.csv'
OUTPUT_FILE = 'dataset/trash_dictionary_full_multilingual2.csv'  # 630件まで trash_dictionary_full_multilingual.csv に保存済み

def translate_chunk(chunk_data):
    """
    30〜50件まとめてAIに翻訳を依頼する関数
    """
    prompt = f"""
    あなたはプロの翻訳家で、データエンジニアです。
    以下のCSV形式の日本のゴミ分別データを、7ヶ国語に対応したJSON形式に変換してください。
    
    元のデータ形式: 品目, 分別区分, 手数料, 備考
    
    出力してほしいJSON形式のリスト:
    [
      {{
        "name_ja": "元の品目",
        "name_en": "英語翻訳",
        "name_zh_cn": "中国語簡体翻訳",
        "name_ko": "韓国語翻訳",
        "name_vi": "ベトナム語翻訳",
        "name_ru": "ロシア語翻訳",
        "name_id": "インドネシア語翻訳",
        "note_ja": "元の備考",
        "note_en": "備考の英語翻訳(短く)",
        "fee": "元の手数料",
        "trash_type_str": "元の分別区分"
      }},
      ...
    ]

    JSONのみを出力してください。Markdown記号は不要です。

    ### 翻訳対象データ:
    {chunk_data}
    """
    
    try:
        response = model.generate_content(prompt)
        # 余計な文字を削除
        text = response.text.replace('```json', '').replace('```', '').strip()
        import json
        return json.loads(text)
    except Exception as e:
        print(f"翻訳エラー: {e}")
        return []

def main():
    # 既存のCSVを読み込む
    rows = []
    try:
        with open(INPUT_FILE, encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
    except FileNotFoundError:
        print(f"{INPUT_FILE} が見つかりません。作成してください。")
        return

    print(f"全 {len(rows)} 件のデータを読み込みました。翻訳を開始します...")

    # 出力用CSVの準備
    headers = [
        'name_ja', 'name_en', 'name_zh_cn', 'name_ko', 'name_vi', 'name_ru', 'name_id', 
        'note_ja', 'note_en', 'fee', 'trash_type_str'
    ]
    
    # 追記モードで開く（途中エラーでも大丈夫なように）
    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()

        # 30件ずつ小分けにして処理 (Batch processing)
        BATCH_SIZE = 30
        for i in range(631, len(rows), BATCH_SIZE):  # 631件目から開始(630件まで翻訳済み-->trash_dictionary_full_multilingual.csv)
            chunk = rows[i : i + BATCH_SIZE]
            print(f"処理中: {i+1} 〜 {min(i+BATCH_SIZE, len(rows))} 件目...")
            
            # AI用のテキストデータ作成
            chunk_text = ""
            for row in chunk:
                # 必要な列だけ結合
                chunk_text += f"{row.get('品目')},{row.get('分別区分')},{row.get('手数料')},{row.get('備考')}\n"
            
            # AI翻訳実行
            translated_list = translate_chunk(chunk_text)
            
            if translated_list:
                for item in translated_list:
                    # エラー回避のためデフォルト値設定
                    writer.writerow(item)
                print(" -> 保存完了")
            else:
                print(" -> 翻訳失敗（スキップします）")

            # API制限にかからないように少し休憩
            time.sleep(2)

    print(f"✅ 全ての翻訳が完了しました！ '{OUTPUT_FILE}' を確認してください。")

if __name__ == '__main__':
    main()