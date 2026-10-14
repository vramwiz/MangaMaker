# MangaMaker の作業方針

最初に `README.md`、`note.md`、仕様書 `AIComicStudio_BBE698A4E88E81E3A882%81.md` と Git の状態を確認する。

## 同階層のプロジェクト参照

このリポジトリは `DelphiProg/MangaMaker` に置き、同じ親フォルダーのプロジェクトを相対パスで参照できる。

- `../MapRaku/`: アイコン、ツールパレット、線種 UI の参考。
- `../SYNC_ScreenLayout/`: `ScreenDesignMaker.dpr`、文字編集、IME、文字描画の参考。
- その他の同階層プロジェクトも、必要な実装を調べる際に参照できる。

具体的な参照ファイルは `note.md` の「読み取り参照元」に記載する。参照先のプロジェクトに作業指示がある場合はそれも確認する。参照先への変更が依頼範囲に含まれない場合は読み取りにとどめ、既存の未コミット変更を保持する。

現行の MangaMaker は `Source` 配下に必要な実装を持つ。同階層のソースを参考にするためだけに、Delphi の検索パスへ他プロジェクト全体を追加する必要はない。

## ソース構成と肥大化の防止

- コメント・分割の基準は `note.md` の「コメント・肥大化防止の規約」に従う。日本語で責務・目的・判断理由・制約を書き、日本語を含むPascalはUTF-8 BOM付きとする。
- 最新ユーザー指示により1ユニット1500行程度を目安とする。1メソッド50行、1フォルダー5～8ユニットは引き継ぐ。行数以内でも責務の混在を確認する。
- `Source/Shell` はフォームの状態管理・ライフサイクル・イベント入口、`Source/Workspace` は各編集機能の処理を担当する。独立したモデルや計算処理はそれぞれの機能フォルダーへ置く。
- モデルは `Model`、描画は `Rendering`、編集計算は `Editing`、文字/IMEは `Text`、管理画面は `Dialogs`、外部連携は `Integration`、出力は `Export`、共通コントロールは `Controls`、計測は `Diagnostics` に配置する。
- 共通効果素材の分類・登録は `Materials` に配置し、素材パネルやCodex通信と責務を分ける。
- 自己検証は `Source/Tests` に分野別で置き、フォームへ検証コードを戻さない。`-SelfTest` 指定時だけ `MANGAMAKER_SELFTEST` を定義して組み込む。
- `Tools/CheckSourceLayout.ps1` をビルド前に実行する。1ユニット1500行、1フォルダー8ユニットを上限とする。上限に達したら責務で分離し、空行削除や巨大なincludeファイルで回避しない。

## ビルドと Git

- 検証は `./build.ps1 -SelfTest -OutputDirectory 'TestOutput/Verified'` を使用する。出力と仮データは `TestOutput` 内に置く。
- Git の `origin` は `https://github.com/vramwiz/MangaMaker.git`。`main` は `origin/main` を追跡する。
- commit/push の際は対象差分を確認し、生成物や他プロジェクトの変更を含めない。認証情報はソースや文書へ保存しない。
