# ローカルパイプ・プロトコル version 1

MangaMakerの通常起動が作る `DataRoot/Runtime/bridge-{PID}.json` の `pipe` を使用する。接続先を明示し、複数の起動を自動的に選ばない。同じWindowsユーザーのローカル接続に限定し、ネットワークのパイプ名は使用しない。

UTF-8、JSONオブジェクトにLFを付けて送信し、1接続に1要求を扱う。JSONの文字列内改行は `\n` などでエスケープする。要求は1MiB、応答は4MiBまで。接続後30秒以内に送信・読込を終え、応答を読み終えたら接続を閉じる。サーバーは終了時に接続中のI/Oを取り消す。

## 接続例

```powershell
$state = .\Tools\MangaMakerBridge.ps1 -ManifestPath '対象データ領域\Runtime\bridge-1234.json'
$state.data.project
```

`-RequestFile` でUTF-8の要求JSONを指定できる。`-RequestJson` で1つの要求を直接指定することもできる。通常のデータ領域はWindowsのドキュメントの `MangaMaker`。試験時は起動したアプリの `MANGAMAKER_DATA_ROOT` を使用する。

## 要求と応答

すべての要求は数値の `version:1` と文字列の `action` を含む。任意の文字列 `requestId`（128文字まで）は応答にそのまま返す。重複するJSONキーは拒否する。

```json
{"version":1,"action":"status","requestId":"state-1"}
```

成功応答は `{"ok":true,"data":{...}}`。失敗は `{"ok":false,"error":"理由"}`。保存完了後にプレビュー更新が失敗した場合は、成功のまま `data.warnings` に文字列の配列を返す。プレビュー警告を登録失敗として再送しない。

`requestId` は再送を重複排除するキーではない。通信の結果が不明なときは状態/対象IDを再照会する。登録時の `expectedFileName` を併用すると、旧参照からの繰返し採用を拒否できる。

| action | 入力 | 主なdata |
| --- | --- | --- |
| status | 追加指定なし | version、canProduce、共通キャラ書込可否、project、selection |
| list_presets | 追加指定なし | 共通の名前・指示本文、書込可否 |
| list_assets | library、画像の場合projectId | assets配列 |
| read_asset | library、assetId、画像の場合projectId | asset、parent、source、references |
| create_asset | library、name、任意notes/parentId | 作成したasset |
| register_image | library、assetId、sourcePath、任意expectedFileName | 採用したasset |

`library` は `characters` または `images`。画像の全要求には状態照会で取得した正確な `projectId` が必要。作品が切り替わっていたら拒否する。編集操作途中や別の入力ダイアログを開いている間の変更も拒否する。画像管理/キャラ管理の選択変更は登録先に影響せず、`assetId` が対象を固定する。

## キャラと服装

`parentId` 未指定で人物の親、親のIDを指定すると服装の子を追加する。子のIDを親として3階層にしない。`read_asset` は選んだ状態の画像と親の画像、共通人物ID/名前/外見補足、状態名/補足を提供する。管理画面の編集中値は `draftName` / `draftNotes` と `draftCharacterName` / `draftCharacterNotes` に含む。

```json
{"version":1,"action":"create_asset","library":"characters","parentId":"親のID","name":"冬の制服","notes":"状態の補足"}
```

画像採用はローカルPNG/JPEG/BMPの絶対パスで指定する。アプリは画像を検証し、管理領域の新しいファイルへコピーしてから参照を保存する。採用失敗では旧参照/旧画像を保持する。保存成功の後はプレビューとツリーを更新する。承認ボタンはない。

```json
{"version":1,"action":"register_image","library":"characters","assetId":"作成した状態ID","sourcePath":"D:\\生成画像\\character.png","expectedFileName":""}
```

## 背景、子画像、タイトル

画像の `create_asset` は `mode` を指定できる。省略時は参照元があればchild、それ以外はscene。

- scene: 独立した背景の親。参照元/人物は指定しない。
- child: 背景の親を参照する子。`sourceId` または `parentId` を指定。
- alternate_scene: 参照元の背景と場面IDを共有する別位置の背景。親階層に置く。
- title: 既存の子画像を `sourceId` で参照するタイトル用子。同じ親の下に置き、作品タイトル/話数をスナップショットする。

```json
{"version":1,"action":"create_asset","library":"images","projectId":"作品ID","mode":"child","sourceId":"背景ID","name":"本文の画像","notes":"子の追加指示","characterIds":["必要な人物または服装のID"]}
```

人物参照は複数または0件を選べる。新規要求の不明ID/重複IDは拒否する。`read_asset` は指定した参照だけを `references` 配列へ含め、全キャラを暗黙に返さない。保存済みデータで参照が見つからない場合は `missing:true` を返し、元IDを捨てない。元画像が見つからなければ `sourceMissing:true`。

適用済み生成指示は `status.data.project.generationInstructions`。共通プリセットの後日編集に影響されない本文スナップショットを、個別の画像指示と組み合わせる。正式な作品保存はユーザーの保存操作で行い、パイプ登録は作業データとUndoへ反映する。画像管理中は、その管理操作の履歴へまとめる。

この入口はユーザーからの生成指示に従って状態照会・ファイル登録を行うためのもの。アプリからCodexへ自動で生成依頼を送る動作は含まない。

## 台本の連続生成とCodexからの画像受信

既存の画像管理を開いたまま、ユーザーの生成指示に従って以下を使用する。作品IDは `status` の現在値を使う。

| action | 入力 | data |
| --- | --- | --- |
| read_script | projectId | source（原文）、plan、sequenceActive、generatedCount、activeAssetId、stage、status |
| generation_context | projectId、assetId | context、fingerprint |
| start_script_generation | projectId、任意limit（0～10000の整数、0/省略は全件） | started、status |
| cancel_generation | projectId | cancelled |

`plan.items` は台本順に `scriptId` / `assetId` / `page` / `status` / `reason` を返す。状態は completed（取得済）、ready（生成可能）、waiting（背景/初登場待ち）、deferred（未完・保留・参照不足）。`nextAssetId` は次のready項目。取得済みの判定は管理ファイルの実在も確認する。台本を再読込して不足を修正した後に再開できる。

`generation_context` は通常の画像生成と同じ説明・適用済み共通指示・背景・登録人物・固有人物の初登場画像を返す。`referenceFiles` の画像を読み、内蔵画像生成で1枚を生成する。`characterContinuity` の画像は指定された役の外見の参照に用いる。群衆は固定しない。

Codexで生成したファイルは、既存の `register_image` で対象UIDへ登録する。`expectedFileName` に生成開始時の `asset.file`（未取得なら空文字）を、`expectedContext` に取得した `fingerprint` を指定できる。条件や参照画像が変わった場合は登録を拒否する。結果が不明なときは対象を再照会する。ユーザーの正式保存操作は従来どおりで、登録は作業データとUndoへ反映する。

```json
{"version":1,"action":"start_script_generation","projectId":"作品ID","limit":2}
```

連続処理は既存の専用Codex接続・画像受信処理を繰り返す。各画像を登録してから次を選び直す。取得済み画像を上書きしない。失敗、中止、作品/管理画面の切替、生成条件変更では停止し、以前の完了画像は保持する。管理画面を閉じた後に裏で継続しない。画像の登録に成功し表示更新だけ失敗した場合は登録済みとして扱う。

現時点の自動処理範囲は画像取得まで。セリフは `source` から参照できるが、吹き出しの作成/配置/文字反映は従来の編集操作。画像に文字・吹き出しを焼き込む実験や自動配置は別途判断する。
