# MangaMaker の作業方針

最初に `README.md`、`note.md`、仕様書 `AIComicStudio_BBE698A4E88E81E3A882%81.md` と Git の状態を確認する。

## 同階層のプロジェクト参照

このリポジトリは `DelphiProg/MangaMaker` に置き、同じ親フォルダーのプロジェクトを相対パスで参照できる。

- `../MapRaku/`: アイコン、ツールパレット、線種 UI の参考。
- `../SYNC_ScreenLayout/`: `ScreenDesignMaker.dpr`、文字編集、IME、文字描画の参考。
- その他の同階層プロジェクトも、必要な実装を調べる際に参照できる。

具体的な参照ファイルは `note.md` の「読み取り参照元」に記載する。参照先のプロジェクトに作業指示がある場合はそれも確認する。参照先への変更が依頼範囲に含まれない場合は読み取りにとどめ、既存の未コミット変更を保持する。

現行の MangaMaker は `Source/Shell` 内に必要な実装を持つ。同階層のソースを参考にするためだけに、Delphi の検索パスへ他プロジェクト全体を追加する必要はない。

## ビルドと Git

- 検証は `./build.ps1 -SelfTest -OutputDirectory 'TestOutput/Verified'` を使用する。出力と仮データは `TestOutput` 内に置く。
- Git の `origin` は `https://github.com/vramwiz/MangaMaker.git`。`main` は `origin/main` を追跡する。
- commit/push の際は対象差分を確認し、生成物や他プロジェクトの変更を含めない。認証情報はソースや文書へ保存しない。
