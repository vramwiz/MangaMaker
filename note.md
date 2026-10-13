# MangaMaker 作業記録

## 継続開発セッション（2026-10-13 07:40 UTC開始）

作業先は `D:\DelphiProg\MangaMaker`。約8時間の継続開発と終了時の対象差分 commit/push が今回のユーザー指示。以下の以前の停止条件・commit/push未許可という記録は歴史的記録で、今回へは適用しない。

- 開始時: `main`、`origin/main`追跡、remote `https://github.com/vramwiz/MangaMaker.git`、HEAD `330073f`。既存差分は README/note のクローン説明と未追跡 AGENTS.md。すべて保持し、`TestOutput/Session-20261013-0740/Initial/` にソース・文書・既存diffを退避。
- この配置に `.agents/skills` はない。同階層 `../SYNC_ScreenLayout/` と `../MapRaku/` は実在、旧 `D:\DelphiProg\test\SYNC_ScreenLayout` は不在。同階層を読み取り参照し、別プロジェクトは変更しない。
- 指定ビルドは通常sandboxでDelphiのレジストリ参照が拒否された。承認された `require_escalated` で同じ `./build.ps1 -SelfTest -OutputDirectory 'TestOutput/Verified'` を実行し、コンパイル成功。出力・データはTestOutputのみ。
- 既知のUndo FAILを再現・診断。テンプレート独立性検証が実クリック座標 `99.683044434` を固定値 `100` に書き戻し、Boundsを更新せず後続検証へ渡していた。実頂点配列を退避し `SetVertices` で復元する修正で **361 PASS**。Undo判定は弱めず維持。証跡 `TestOutput/112abed1b1374777a4d286221e1d89e1/`。
- 優先順: ライブラリ読込失敗時の元データ保護・作品切替中の作成状態漏れを修正し、回帰基準を確立。その後、文字入力の移動/スクロール/IME/組版と、ページ基準やコマ操作の重要仕様を段階的に進める。
- 安全性段階: `ReadAssets` は全件/全パス検証後に公開し、失敗時に元リストを変えない。起動読込失敗時のキャラ管理は読み取り専用で、終了してもLibrary.jsonを書かない。修復後に開き直すと再読込する。新規/読込は `AdoptProject` に集約し、作品入替前にドラッグを取り消し、ポリゴン/対角点/分割/選択/履歴をリセット。隔離不正Library fixtureと作品切替を含め **371 PASS**。証跡 `TestOutput/cdac5b13e8ab48dabffab6c34ae670aa/`、ログ `TestOutput/Session-20261013-0740/Safety-build.log`。
- 文字段階（08:24 UTC頃）: 横入力の上下/縦入力の左右による表示行・列移動、単語移動・削除、入力内100段階Undo/Redo、カーソル追従/バー/ホイールの長文スクロールを実装。`ComicTextUnits` はサロゲート、CRLF、結合濁点/異体字セレクタ/主なZWJ絵文字/旗のペアをまとめて扱う（Unicode全書記素アルゴリズムの完全実装ではない）。`ComicTextLayout` を入力とRendererで共有し、句読点/小書き仮名の位置、長音/括弧/英字回転、2桁数字の縦中横、基本禁則を追加。入力領域と吹き出し領域/文字サイズは異なるため最終改行一致を保証しない。
- IME受取はGCS_RESULTSTRを一括通知しDefWindowProcによる二重挿入を避け、WM_CHARのサロゲートは完成してから1回通知。未確定文字も縦/横配置へ挿入表示し、候補位置を疑似カーソルへ設定。`WindowsImeController` は退避HIMCと変換/文節モードを保持し、imDisableで切り離した後も復元する。隔離HIMCでライフサイクル確認。実IME候補/変換/他アプリへの復帰は画面操作手段が利用できず未検証。
- 文字段階 **423 PASS**、4797行コンパイル、エラー/警告/ヒントなし。96/144 PPIの長文・IME未確定縦配置・入力取消/作品確定/保存再読込/UndoRedo、縦文字の翻訳DC全画素比較、既存の幾何/差分PNG/出力失敗回帰までPASS。証跡 `TestOutput/0903581384cc42f391ede45ab205d96e/`、ログ `TestOutput/Session-20261013-0740/Text-layout-build.log`。Renderer署名を `renderer-6` へ更新し、旧PNGキャッシュは一度描き直す。
- ページ基準段階（08:45 UTC）: 全ページ共通の出力幅/高さ・上下左右余白を作品に保存。「設定・管理 → ページ基準・共通プリセット」で変更/共通登録/名前変更/削除。配置済み座標を維持し、適用は作品Undo。外枠スナップ/外枠超過表示/ガイドも設定を参照。共通ライブラリは `Presets/PageBases.json`。独立した作品スナップショットなのでプリセットを変更/削除しても適用済み作品は変わらない。取消・保存再読込・Undo/Redo・不正値・読込失敗・書込ロックからの登録/名前変更/削除復旧・96/144 PPIを含め **461 PASS**。証跡 `TestOutput/4009183fc4bb4b1180f46a09f55e999b/`、ログ `TestOutput/Session-20261013-0740/Page-basis-build.log`。解像度変更で全ページ再描画、余白のみの変更はPNGキャッシュ再利用。
- 複数コマ段階（08:55 UTC）: Ctrl+クリックでUIDによる追加/解除、全体8点で縦横独立変形、コマ間の空白からも全体移動、Ctrl+A/Deleteで全コマ選択/一括削除。すべての候補形を検証してから公開し、無効な1コマによる部分変形を防ぐ。画像UID/元画像を保持し、相対パンを比率変形。吹き出しのページ位置は単独コマ編集と同じく維持し、コマ削除時は所属吹き出しも削除。1操作Undo、Esc取消、全8ハンドル、混合形状の保存再読込、極細コマを含む原子的拒否、96/144 PPIの実VCLメッセージ回帰を含め **505 PASS**。5497行、エラー/警告/ヒントなし。証跡 `TestOutput/d5e2d77e0f924348a774dbc8697dc14f/`、ログ `TestOutput/Session-20261013-0740/Panel-group-build.log`。
- 共通テンプレート管理段階: 登録したコマ割りの名前変更/削除を右管理パネルへ追加。組込テンプレートと読込失敗ライブラリは操作を無効化。名前変更はUID/形状を維持、削除は適用済みページを維持。書込ロック時は名前/項目/順序を元へ復元し、不正な後続項目の読込で部分公開しない。証跡 `TestOutput/d663819f395a463cac6ae799ab36f02b/`、ログ `TestOutput/Session-20261013-0740/Layout-library-build.log`。ソース退避 `TestOutput/Session-20261013-0740/VerifiedSource-TemplateStage/`。
- 文字装飾段階: フォント名/サイズ/色、全文一律の太字/斜体/下線/取消線を保存・描画し、専用入力へ同じ属性を渡す。フォント履歴は適用完了時に内部更新し、次回ドロップダウンを開くまで選択リストを並べ替えない。履歴は最大10件、読込不正や書込失敗で既存状態を保持。**538 PASS**、証跡 `TestOutput/ef4d101b676e40998b43f6bb97ef0c5f/`。フォント変更で長文のレイアウトとスクロールも更新する。自己検証の成長に合わせbuild.ps1の時間制限を60秒へ変更し、結果読込のUTF-8を明示。
- 追加レビューP2（09:32 UTC修正検証）: 旧A/B複数選択後にCを作ると主選択だけCへ変わりUIDリストがA/Bのまま残る経路を修正。`SelectSinglePanel`で四角/多角形/分割の選択を同期し、Ctrl追加選択も主選択を基準に同期。四角/多角形それぞれ作成→D追加→削除→Undo→保存再読込の実VCLイベント回帰を追加。**552 PASS**、証跡 `TestOutput/356c78def48245e68e36ebfb1fd2644a/`、ログ `TestOutput/Session-20261013-0740/Created-selection-build.log`。
- 複数しっぽ段階（09:53 UTC）: 本体所有リスト、三角/3つの丸による思考しっぽ、2点作成/根元・幅・先端3点編集/個別削除、全尾追従、文字サイズ追従、四角本体、塗り/縁色/固定出力px縁太さを実装。形状を保持して描画時に輪郭合成し、接続部の内部縁を描かない。新しい作品保存はversion3、version1/2の単一しっぽは安定した既定IDで読込。Renderer署名 `renderer-7`。**604 PASS**、6304行、エラー/警告/ヒントなし。2点作成の保留/取消・3点全操作・個別削除・全尾/文字追従・保存再読込/UndoRedo・クリップ/透明・思考丸・翻訳DC全画素比較・96/144 PPI・差分PNG/出力後Undoを確認。証跡 `TestOutput/a9f8aebf203e4732afa6de3e44037a2f/`、ログ `TestOutput/Session-20261013-0740/Tail-ui-build.log`。画像で輪郭と3点編集を確認済み。
- 文字配置段階（10:07 UTC）: 本体内の中央へ文字ブロックを配置。文字配置ツールで文字だけの移動/比率維持8点拡縮を追加し、相対オフセットは本体へ所有させて保存・追従する。自動縮小は行わず、はみ出しを許容。全8点、取消、Undo、フォントサイズ表示同期、全体の独立軸拡縮に伴う文字オフセット追従、原子的拒否、保存再読込、縦/横×96/144 PPIを確認。証跡 `TestOutput/6ab6abecbe6a407d84684f341bef4d55/`、ログ `TestOutput/Session-20261013-0740/Text-placement-build.log`。Renderer署名 `renderer-8`。
- 参照プロジェクトのGit状態を昇格読み取りで確認: SYNC_ScreenLayoutは差分なし。MapRakuは既存の多数の変更あり（Editor/Map/Rendering/Tests等）。これらは触らず、今回の対象commitへ含めない。文字参照4ファイルのSHA-256一覧を `TestOutput/Session-20261013-0740/ReadOnlyReferences.csv` に記録。
- IME実装で確認した一次資料: [WM_IME_COMPOSITION](https://learn.microsoft.com/en-us/windows/win32/intl/wm-ime-composition)、[ImmSetCandidateWindow](https://learn.microsoft.com/en-us/windows/win32/api/imm/nf-imm-immsetcandidatewindow)、[ImmSetCompositionWindow](https://learn.microsoft.com/en-us/windows/win32/api/imm/nf-imm-immsetcompositionwindow)。ScreenDesignMaker参照の追加: `../SYNC_ScreenLayout/Source/Core/Geometry/Text/ScreenLayoutTextGeometry.pas`（読み取りのみ）。
- 親スレッドへの最初のアプリ内メッセージ送信は `thread not found`。この環境の通知・作業コメントと本noteに進捗を記録する。

- 生成プリセット段階（10:33 UTC）: 共通指示の追加/名前・本文編集/削除、作品への明示適用を実装。作品は選択した名前・本文のスナップショットを保存し、共通側の後日編集/削除の影響を受けない。共通保存の失敗は項目/順序/本文を復元。画面で編集した未保存の本文も作品に適用できるが共通側へ暗黙保存しない。672 PASS、証跡 `TestOutput/78f59e1b01dc4ca3ae44c0a92e37b79c/`。
- 追加レビューP2（10:49 UTC修正検証）: 文字拡縮でフォント変更後に本体幅で再折返しする経路を修正。初回拡縮で折返し基準領域・フォントを保存し、セル配置を均一拡縮する。文字本文/縦横/フォント名/装飾を明示編集した場合は新しい基準へ再配置する。描画は基準レイアウトと画面サイズを分離し、GDI変換下でのフォント計測の不安定性を避ける。縦横×96/144 PPI×全8点の折返し・幅高さ比・保存再読込・Undo/Redo/取消を含め **872 PASS**、6871行、警告/エラーなし。証跡 `TestOutput/49e346aa116a4b88b4303e1f448a9897/`、ログ `TestOutput/Session-20261013-0740/Text-scale-build.log`、Renderer署名 `renderer-9`。

- ローカル連携段階（11:08 UTC）: `ComicBridge` に作成ユーザーSID限定ACL・リモート拒否・インスタンス名・manifest・UTF-8/LF/1要求/サイズ・時間制限・overlapped I/O取消を実装。状態/選択/親情報/生成指示照会、ID固定の親子作成と画像登録をMain側で扱う。画像は検証後に新規ファイルへコピーし、書込失敗で旧参照へ復元・新規コピーのみ削除。作品はDraftへ保存してUndo、管理画面を開いている間は外側の1操作へまとめる。元画像は削除しない。PowerShell helper `Tools/MangaMakerBridge.ps1` を同梱。実パイプと別PowerShellプロセスで照会・日本語本文、選択変更後のID登録・競合・不正要求・読取専用・保存ロック失敗・UndoRedo・通信中断終了を確認。912 PASS、証跡 `TestOutput/905647259c1845328ead1100e5eb2542/`、ログ `TestOutput/Session-20261013-0740/Bridge-build.log`。物理IME/他ユーザー資格での接続は未検証。素材読込は重複ID/孤立した親/3階層を拒否。
- パイプ実装の一次資料: [Named Pipe Security](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights)、[SDDL変換](https://learn.microsoft.com/en-us/windows/win32/api/sddl/nf-sddl-convertstringsecuritydescriptortosecuritydescriptorw)。既定ACLを使わず、重複した操作名も拒否する。

- 追加レビューP2（11:14 UTC）: 選択中Aの参照画像が外部で破損し、Bの作成/登録保存後のAプレビュー更新が失敗する経路を再現。プレビューは元の参照を保持して警告表示し、保存完了後の画面更新例外も `data.warnings` へ分離して `ok:true` を維持する。期待する旧fileを指定した再試行は競合で拒否し二重採用を防ぐ。破損修復後の選択継続も実パイプで検証。
- 人物・服装段階（11:18 UTC）: 共通人物ID/名前/外見補足と状態名/補足を分離。親切替は各素材ID/画像/共通IDを保持し、旧親と他の子を新親へ付け替える。管理画面の子右クリックで実行。親ドラッグはグループ一式、子は同じ人物内で並べ替え、展開状態を復元。書込失敗はオブジェクト自体を破棄せずフィールド/順序/選択を復元する。実ツリーのドラッグイベント、異人物への移動拒否、保存再読込、ロック失敗、保護モード、96/144 PPIを含め **956 PASS**、7782行、警告/エラーなし。証跡 `TestOutput/feda9ad4045142f1bab2432a3ab6d27f/`、ログ `TestOutput/Session-20261013-0740/Character-groups-build.log`。隠したVCL描画で人物/状態の入力欄とツリーを確認。

- 場面生成段階（11:32 UTC）: 子の参照人物/服装選択（0件可）・別位置の兄弟背景・元の子を参照するタイトル用派生子を追加。元画像IDと場面IDを持ち、タイトル/話数は派生時のスナップショット。ツリーは2階層のまま。パイプcreate_assetのmode/sourceId/characterIdsと、read_assetの選択した人物参照だけの照会へ対応。既存の不明な参照IDは選択画面で保持して明示解除できる。画像管理の生成プリセット/パイプ採用/管理編集は閉じた際の1操作Undoへ集約。参照選択の取消・ゼロ件・DPI、不正ID拒否、保存再読込、UndoRedoを含め **979 PASS**、8079行、警告/エラーなし。証跡 `TestOutput/9a8ba83a8d174c9483714714852a2c08/`、ログ `TestOutput/Session-20261013-0740/Scene-generation-build.log`。

- 漫画効果段階（12:20 UTC）: Ctrl+5の素材/フィルター/枠装飾タブ、組込透明PNG（コードで描く集中線/スピード線/キラキラ）と共通PNG管理、複数素材D&D/比率維持8点/移動/削除/取消、セピア/モノクロ/ぼかし/夢の強度、通常/二重/破線と色・出力px太さを実装。素材はコマ相対配置、採用PNGを作品内Effectsへコピーし共通削除から独立。コマ分割では元の全体素材位置を両断片で保持し、第2断片の素材IDを新しくする。テンプレートは効果を含めない。共通管理中の変更通知で主一覧を即時更新し削除済みオブジェクト参照を残さない。フィルターの一時描画はページとコマの交差へ限定し、画面外の巨大コマ全体を確保しない。
- 漫画効果 **1118 PASS**、8905行、警告/エラーなし。透明半分の実画素合成、全8点、取消/保存再読込/Undo、複数素材/個別削除、4フィルター、ぼかし/輝度の画素、4形状×3枠の翻訳DC全画素、共通ライブラリ不正/ロック、素材削除後出力、素材の同パス更新検出、分割位置/ID、96/144 PPI移動・全8点取消・管理ボタンを確認。出力後UndoはOutputRevisionを未確定へ戻す既存仕様を保持し、編集状態とPNGキャッシュ再利用を別に確認。証跡 `TestOutput/e03e5f59a7d74a6ea53134f472589893/`、ログ `TestOutput/Session-20261013-0740/Effects-ui-build.log`、Renderer署名 `renderer-10`。

- 追加レビューP1/P2（12:40 UTC）: ドラッグ途中のコマンドは取消によるProject.Restore後に現在の対象を取得する。効果削除/フィルター/枠/画像解除/頂点/分割/しっぽ/画像管理、ページ並替で事前のオブジェクト参照を保持しない。ドラッグ中Delete・他コマ操作・ページ並替・Undo/Redo/取消を隔離イベントで確認。ぼかし等はページ出力pxで計算したラスタを共通利用し、48MiB上限のキャッシュで縮小表示を再利用する。25/50/75%表示が出力縮小の全画素と一致。9023行、警告/エラーなし、証跡 `TestOutput/adea078534014144a3a19e5c539beb10/`、ログ `TestOutput/Session-20261013-0740/Effects-review-build.log`、Renderer署名 `renderer-11`。

- 履歴・間隔段階（13:02 UTC）: 正常読込/保存の履歴を最新20件で保持し、Windowsパスの大小文字で重複排除。保存失敗は元順序へ復元。不正履歴や作品/Draftの読込で既存作品/履歴を置換しない。元のProject.jsonを保持しDraft復元を選べる。間隔は軸方向が重なる近隣の非多角形コマの外接範囲から推定し、自己除外/非近隣の距離除外を行う。作成/頂点スナップへ反映し、近い候補と既存角・辺の同距離優先を保持。96/144PPI、Alt/設定解除、取消、保存再読込/Undoを含め **1186 PASS**。証跡 `TestOutput/dcd84fab77ce4faebd1ed3658dcc5095/`。
- 検証準備の画像一覧更新漏れで、このセッション起動の隔離self-testのみ通知ダイアログに待機。パス/PID/固有fixture引数で対象を確認して通常終了を要求したが閉じなかったため、そのテストだけ停止。既存アプリは操作していない。準備修正後の検証はPASS。Mainの通知は自己検証時に例外として返し、同じ待機を防止する。
- 出力取消・負荷段階（13:19 UTC）: 出力オプションを開く前に未確定ドラッグを取消し、取消後の編集データ/Undo保持・96/144PPIの全ボタン到達を確認。固定ダイアログの検証ではネイティブ生成後に論理サイズを明示する。80ページ/480コマ・吹き出しのUnicode保存再読込、小サイズ240x360の80枚PNG、未変更全キャッシュ・1枚差分、ページ外7万px範囲のぼかし、6000文字縦/横描画を確認。証跡 `TestOutput/aef5007a4b454cee981b53aeb48e33ff/`、ログ `TestOutput/Session-20261013-0740/Bulk-data-build.log`。performance.txt実測: 保存78ms、読込16ms、初回80枚1406ms、未変更188ms、巨大範囲125ms、6000文字各78ms。小サイズ出力・この環境の結果で、通常解像度の長期制作負荷や実IME/DPIモニター切替は未確認。
- 13:16 UTC時点にorigin/mainを再取得し、HEAD/origin/mainとも `330073fb6840bafadd51b4128a675039c70fc63e`。GitHub Actions定義はこのcheckoutにない。終了時の対象差分commit/pushとremote一致確認はまだ行っていない。

- 最終検証の準備（13:24 UTC）: Debugは **1203 PASS**、9404行、警告/エラーなし（fixture `TestOutput/aef5007a4b454cee981b53aeb48e33ff/`）。同じソースのWin64 Releaseもコンパイル成功・全項目PASS（fixture `TestOutput/42c37fad629b4f36a468c01e22cd176d/`、ログ `TestOutput/Session-20261013-0740/Release-build.log`）。両構成で出力先引数不足/隔離環境不足のCLIガードがフォーム生成前のexit2、出力ファイル0件を確認。プロトコル詳細を `Tools/LocalBridge.md` に記載。機能追加を抑え、関連操作と資料の整合・対象差分・最終レビューへ移る。

### 最終候補の点検（14:04 UTCまで）

- 通常サイズの負荷検証を追加。1200×1700px・6ページ・12コマへ2400×3200px BMPと75%ぼかし、縦横の長文を配置し、保存再読込・6枚PNG・未変更0枚再描画を確認。最新実測は初回約11.2秒。80ページ検証は240×360pxなので、両条件を区別する。長時間の実制作負荷を保証する測定ではない。
- 出力オプションの実 `ShowModal` ループへ閉じるメッセージを送り、96/144 PPIで取消結果と作品/Undo履歴の保持を確認。物理キーやクリック、実モニターのDPI切替は未検証。5画面すべてについて通常/狭い画面、効果3方式とスクロールによるボタン到達も確認し、画像を目視した。
- 別作品IDのDraft、重複ページID（Windowsで同じ保存/キャッシュパスになる大文字小文字違いを含む）、0px文字を拒否し、現在の作品を維持する回帰を追加。
- IME受取欄のHIMCが切り離されたときの退避欠落を隔離fixtureで再現し、既存のスレッド既定HIMCを一時関連付けして開閉/変換状態を退避後、元の切離しへ戻す修正。実VCLのフォーカス入退/再入メッセージと非テストモードの入力セッション終了を確認。VCL `Vcl.Controls.pas` / `Vcl.Forms.pas` のIME設定・フォーカス順序を読み取り参照した。実候補選択/実変換は引き続き未検証。
- 最新全体検証は **1250 PASS**、9511行、警告/エラーなし。fixture `TestOutput/30835063aeb54090ba4396c5ff62023c/`、ログ `TestOutput/Session-20261013-0740/IME-reentry-build.log`。この後、実際にAPIが返した開閉状態のINFO記録と変換モード復元チェックを加えて最終再検証する。
- Dドライブの空き不足で1回の検証がPNG書込時に失敗。今回作った361～552検証の8つの過去fixtureを一時領域で圧縮し、全ファイルの長さ・SHA-256を元と照合してから重複元を整理した。ZIPと照合manifestは `TestOutput/Session-20261013-0740/ArchivedFixtures/` に戻して保持（約18MB、元約848MB）。元のfixtureフォルダーを参照する場合は同名ZIPを `TestOutput/{fixtureID}/` へ展開する。開始前のデータ・実作品・別プロジェクトは整理対象外。初期ソース退避と現在の証跡は維持。

### 今回の再開基準

1. この冒頭のセッション記録を現行とし、以下の360/332検証や未実装一覧は過去の記録として読む。現行の制限はREADME末尾を参照する。
2. `./build.ps1 -SelfTest -OutputDirectory 'TestOutput/Verified'` と必要に応じ `-Configuration Release -OutputDirectory 'TestOutput/Verified-Release'`。fixtureは1回約170MB増えるので空きを確保し、過去の仮データを整理する場合も今回のように対象と保存内容を照合する。
3. 次の実機確認は専用データコピーで、実IME候補/変換と入力欄→ボタン→再入力→終了時の状態、実モニターDPI切替、長時間制作を優先。縦キャレットは横線を維持する。
4. 機能の次候補は本体輪郭のギザギザ/波/雲、コマ全体の移動/拡縮スナップ、さらに高度な組版。既存の保存/取消/Undo/DPIと差分PNG回帰を保持する。

### commit前の最終候補（14:15 UTC）

- 独立レビューは14:09 UTC時点の1251検証で新しい重大指摘なし。その後の追加は文字ダイアログを実ShowModalで開き、横/縦の実フォーカス・取消・破棄後のIME復元を確認する4項目。機能追加は終了し、対象差分と記録を確定する。
- **Win64 Debug/Releaseとも1255 PASS、9523行、警告/エラーなし**。Debug `TestOutput/f176c3381b4a467bb5f0e855e01d39c8/`、Release `TestOutput/db6726af283b44e0a3262c096b7c26ea/`。ログはsession内 `Final-debug-build.log` / `Final-release-build.log`。IME APIのINFOは要求False/観測False、要求True/観測True。変換/文節モードの復元も確認。ただし候補操作・実変換確定・他アプリへ戻る物理操作は未検証。
- 最終バイナリのCLIガードはDebug/Release各2件でexit2・ファイル生成0件。結果と各exeのSHA-256は `TestOutput/Session-20261013-0740/CLI-guards/Final-results.json`。参照したSYNCの4ファイルのSHA-256も一致。ソースの変更対象27 PascalファイルはUTF-8 BOM/CRLFを揃えた。
- Release実測: 通常6ページ/大画像/ぼかしの初回出力10953ms、保存再読込16ms。80小サイズページの初回1421ms/未変更219ms、巨大コマ範囲109ms、6000文字横78ms/縦79ms。新しい大容量テストは行わない。
- 追加で今回の重複1209検証fixture `759de0eb34934b53a6670dc693525576` 1件だけを同じ長さ/SHA-256照合付きでZIP保存。Archivesは合計9件・元約1GB/ZIP等約24MBで、すべてTestOutput内に保持。開始前の出力・ユーザーデータには触れていない。
- commit候補は今回のSource/Shell、Toolsのパイプhelper/説明、build.ps1、README/note、開始時から存在するAGENTS.md。生成exe/DCU/画像/fixture、参照先の差分は含めない。既存README/noteのクローン説明も保持して含める。終了時に通常のcommit/pushとremote SHA、利用可能なCIを確認する。

### 最終同期候補（14:44 UTC、1262検証）

- 最終パイプ点検で、ネイティブのファイル/色選択ダイアログは `Screen.ActiveCustomForm` を置換しないことをVCL実装で確認。書込み対象のMain/素材管理ウィンドウが無効化されている間の登録を拒否するガードを追加。状態照会、Mainだけが無効化された有効な素材管理画面の通常登録は維持する。
- 実パイプで無効化ウィンドウ状態を注入し、Mainへの登録拒否、管理画面の内側のダイアログ状態での登録拒否、ライブラリ全バイト・選択・未確定の補足保持、読取と通常管理登録の継続の7項目を追加。これはダイアログ所有者の状態による回帰で、物理的なファイル選択を操作した確認ではない。機能を増やす変更ではなく既存の登録境界の補強。
- **Win64 Debug/Releaseとも1262 PASS、9552行、警告/エラーなし**。現行Debug fixture `TestOutput/25dc517e80124f09af32a01d0bde49ad/`、Release `TestOutput/1614473244ca489d8e0bf336deb3b82e/`。両exeは `TestOutput/Verified/` / `TestOutput/Verified-Release/`。session内の `Final-debug-build.log` / `Final-release-build.log` とCLIガード `Final-results.json` も更新済み。両構成のCLIは各2件でexit2・生成0件。
- Release実測の通常6ページ出力10813ms、小サイズ80ページ1437ms/未変更203ms。追加の大容量検証ケースは増やしていない。登録ガード変更に対する最終再検証のみ実施。
- その再検証と次の再開用の空きを確保するため、今回の重複1251 fixtureと旧1255候補の2構成も、全ファイル長さ/SHA-256を照合したZIPへ保存。Archivesは合計12件・元約1.55GB/ZIP約43MB。旧1255のfixtureは同名ZIPから復元可能で、現行1262の2構成は展開状態で保持。D空きは約431MiB。開始前のファイル/実作品/他プロジェクトを整理していない。
- 最終記録はsession内 `Final-candidate-files.txt`（33ファイル）、`Final-candidate-hashes.csv`（ソース/文書候補）、`Final-build-source-hashes.csv`（ビルド入力全体）、`Final-verification-hashes.csv`（exe/ログ/結果/性能/CLI）へ同期する。旧1255ソース退避 `VerifiedSource-Final/` と区別し、現行退避は `VerifiedSource-Final-1262/` を使う。
- 実IME候補選択/実変換確定/他アプリへの物理的な復帰、実モニターDPI切替、長時間制作は未検証のまま。READMEの残仕様も維持。これをcommit/push用候補として固定し、この後はソースを変更しない。

更新: 2026-10-13 06:42 UTC。以下は以前の文字入力区切りの歴史的記録。

## 最新の文字入力区切り（06:24～06:44 UTCの許可範囲）

ユーザーがScreenDesignMakerのライブラリ利用と文字入力着手を明示許可したため、以前の文字入力前停止条件をこの範囲で解除した。新しい統合は「専用文字入力」ボタンから開く入力画面。既存TMemoとダブルクリック再入力は保持した。

- `ComicTextEditing.pas`: 参照元`ScreenLayoutTextEditing.pas`のTScreenLayoutImeEdit、選択削除/挿入、サロゲートペアとCRLFを分割しない左右移動を切り出して再利用。Skia依存の計測/組版関数は除外した。
- `WindowsImeController.pas`: 参照元ユニットをコピーして使用。入力開始で状態を保存し、入力終了で無効化/フォーカス通知の後に状態を復元。フォーカス離脱時も元の状態を保つコピーで復元する。
- `ComicTextInput.pas`: 上記ライブラリを使うセッション、初期GDI入力プレビュー、専用ダイアログ。作品を編集中に変更せず、確定で1つのUndo、取消で元を保持する。
- 確定文字はWM_CHARから編集バッファへ渡す。未確定中は全体確定を拒否し、キーをIMEへ渡す。Ctrl+Enterで全体確定、Escで取消。左右/選択/削除/挿入/改行/クリップボードに対応。
- 入力プレビューの疑似カーソルは横組みで縦線、縦入力で横線。参照元の縦キャレット完成実装をコピーしたという意味ではなく、再利用した入力バッファを表示する側でユーザー要件を実装した。

検証は非表示VCLイベントで、Unicode境界/IME開始終了/確定取消/作品保存再読込/UndoRedoと96/144 PPIのカーソル向きを確認。実IME候補表示、実際の変換確定、終了後に他アプリへ戻った際のIME状態復元は未検証。ユーザーアプリにフォーカスを移す自動操作は行っていない。

残り: 上下カーソル移動、単語移動、入力内Undo、長文スクロール、組版に一致するヒット位置/選択、未確定文字の縦組み配置、句読点/結合文字/縦中横など。完成ページRendererの本格組版は未変更で、専用入力プレビューと完全一致を保証しない。実IME確認を行う前に、現在の未検証範囲をユーザーへ説明する。

文字段階のビルド/証跡は`TestOutput/Text-20261013-0624/`。直前の非文字332項目の検証版は`TestOutput/Geometry-20261013-0513/Build/MangaMaker.exe`として保持した。文字段階の確定した検証数、fixture、ハッシュは同TextセッションのVerificationに記録する。以下は非文字段階の記録。

文字段階最終: Win64 Debug、4144行、エラー/警告/ヒントなし、**360項目PASS**。最新fixtureは`TestOutput/63780e8cbab54de39164337f046ae458/`。証跡は`TestOutput/Text-20261013-0624/Verification/`、ソース/定義/説明退避は同セッションの`VerifiedSource/`。元の非文字の再開基準332項目を使う場合はその時点の退避を使い、現行ソースでは360項目を基準にする。

短レビューのダイアログキーP2を修正: 入力EditだけでなくダイアログのKeyPreview/KeyDownでもCtrl+Enter/Escを処理する。ボタンをActiveControlにした確定/取消と、未確定IMEキーを受取側へ渡す回帰を追加。これは非表示VCL状態/イベントの確認で、物理的なTab操作や実IME変換は未確認。ダブルクリックは既存TMemoへ、専用入力は追加ボタンからという導線をREADMEに明記した。

次回はREADMEの専用文字入力手順で専用データを使い、人による実IME候補/確定/取消、Tab移動後のキー、終了時のIME状態復元を確認する。ユーザーアプリへのフォーカス移動を自動化せず、必要なら確認事項を先に報告する。上下移動/長文スクロール/本格組版は現在の基礎統合とは別の区切りとして進める。

## 今回の進捗

指定仕様書 `AIComicStudio_BBE698A4E88E81E3A882%81.md` を基準に、手動で取り込んだ画像からページを編集して連番PNGを作る流れを拡張した。

- 共通コマ割りテンプレート、ページサムネイルと複数ページ操作、8点変形、画像サムネイル・パン・割当解除、内容署名による差分PNGを検証済み。
- MapRakuを読み取り参照した独立アイコンコントロール。画面切替、ツール、キーボード操作、無効表示、96/144 PPIの非表示VCL描画を検証済み。
- 多角形作成・保存・ヒット判定・画像クリップ・テンプレート再利用、外枠/既存頂点/辺へのスナップを実装。
- 四角/凸多角形の4点分割。水平/垂直/斜めの平行帯を除き、2つの多角形を保存。画像のページ上位置・倍率、画像UIDを維持。吹き出しの位置/文字を保持し、所属コマを更新。Undo/Redoと保存再読込を検証済み。
- レビュー指摘の薄い三角形の極端な縮小を修正。候補の全頂点を検証してから確定し、無効なUI縮小は直前の有効形状を維持する。
- 内側の黄色い点による頂点移動、右クリックで頂点削除/辺への頂点追加。四角を多角形へ変換し、画像位置・コマUID・吹き出し所属を保持。交差/重複点/3点未満への削除を拒否。追加した直線上の点も内側へ編集点を表示。移動中は自分自身をスナップ対象から除外する。
- 画像描画とハンドルの座標計算を統一。分割前後の画素比較も通過。大きく頂点を広げた場合の相対倍率10%未満も表現でき、元の画像位置を維持する。出力署名の描画版をrenderer-5へ更新したため、以前のキャッシュは一度再描画される。
- README.mdを新規作成し、使い方.txtを履歴扱いに整理した。Git同期用の説明は相対パスを基本とする。
- 最終レビューのスナップP2を修正。頂点/辺/軸の候補を分離し、全コマを探索後に頂点→辺→軸の順で採用する。コマ順序を反転しても同じ結果になり、同距離時も座標による固定の優先で選ぶ回帰を追加した。

## 検証結果と成果物

正規Embarcadero Delphi 37.0 / MSBuildでWin64 Debugビルド成功。最後のコンパイルは3540行、エラー/警告/ヒントなし。自己検証 **332項目PASS**。別途、引数不足/隔離データ指定不足を終了コード2でフォーム生成前に拒否する2件もPASS。

- 実行ファイル: `TestOutput/Geometry-20261013-0513/Build/MangaMaker.exe`
- 最新fixture: `TestOutput/516f20c5b689435c877c2013f685bb29/`
- 集約証跡: `TestOutput/Geometry-20261013-0513/Verification/`（結果、画像、ハッシュ、概要）
- 再開用ソース退避: `TestOutput/Geometry-20261013-0513/VerifiedSource-332/`（ルート定義/説明と`Source/`）
- スナップ修正前の322項目時点: 同セッションの`VerifiedSource/`と`Verification-322/`。現在のBuildは332項目時点なので、旧証跡と混同しない。
- 以前の区切り: `TestOutput/Icons-20261013-0420/` と `TestOutput/Session-20261013-0324/`

検証対象は保存/日本語/UID、Undo/Redo、テンプレート変換、ページ並替/削除、全方向変形、画像比率/パン、吹き出しフォーカス/しっぽ追従、差分PNG/書込失敗復旧に加え、多角形の成立条件/ヒット/画像と吹き出しのクリップ/テンプレート、四角と凸多角形の分割、画像座標/画素維持、頂点操作、薄い三角形、自己スナップ除外。

96/144 PPIの通常/狭い画面の4モード、下端ボタンへのスクロール/キー到達、96/144 PPIでの実VCLメッセージによる頂点選択/移動/Undo/保存もPASS。これは非表示VCLスケーリングによる確認で、実モニターの設定変更ではない。実IMEの変換操作や、人が長時間制作した体感確認は未実施。

既存コード/未コミット作業はresetしていない。初回/アイコン段階の退避を保持。直下exeに04:51 UTCの他経路更新を観測し、その後の幾何段階ではそのSHA-256が変わっていないことを確認した。原因は未特定で、直下を検証版へ上書きしていない。MapRakuの記録した14参照ファイルのハッシュは再確認時も一致。

## 次回の再開手順

1. 指定仕様書、README、本noteを読む。AGENTS.md/Git状態/進行中の別作業を再確認する。旧exeをソースの現状と混同しない。
2. `./build.ps1 -SelfTest -OutputDirectory 'TestOutput\\Resume'` で新しい隔離ビルドを作る。332 PASSを基準に差異を確認する。
3. READMEのお試し起動で専用データを使い、多角形→画像配置→4点分割→黄色点/右クリック→Undo/Redo→保存再読込→2回PNG出力を手で試す。実作品へ触れる前に複製する。
4. 非文字機能を続けるなら、仕様9.3のコマ複数選択/全体変形、仕様8.1のページ基準プリセット（寸法/外枠）、共通テンプレートの名前変更/削除を優先候補にする。次の一連操作を選んでからスコープを絞る。
5. 名前付きパイプや管理親子操作は状態/UID/ファイル参照から設計する。外部生成や送信は必要になるまでfixtureで検証する。
6. 文字入力に入るなら下記ScreenDesignMakerの参考を再確認し、ユーザーへ現在の制限と方針を報告して区切る。縦カーソルは横線の指定を保つ。

## 制約と次の区切り

楕円/角丸/凹多角形の帯分割、コマ複数選択、間隔スナップ、ページ基準プリセット編集、効果/フィルター/枠装飾、名前付きパイプ、画像生成プリセット、管理画面の親子入替/並替、複数しっぽ/思考しっぽ、作品の読込履歴は未実装。

既知の操作上の制限: 極端に細いコマ/密集した頂点では黄色点と外周点が重なることがある。キャンバスの拡大表示UIは未実装。非常に大きな画像/大量ページ/長時間運用の負荷、実モニターをまたぐDPI変更は未検証。現時点でビルドを阻む問題はない。

以前は文字入力前に停止する方針だったが、最新ユーザー指示により上記20分枠の基礎統合を許可された。本格組版やIME高度処理/フォント履歴は未完。ユーザー指定の参考はScreenDesignMaker（別プロジェクトの`SYNC_ScreenLayout/ScreenDesignMaker.dpr`）。縦入力の疑似カーソルは **横線**。新たなIME/組版方針は参照元とユーザー指示を確認して進める。

参照候補は `ScreenLayoutTextEditing.pas:276` の未確定/確定IME通知とUTF-16編集バッファ、`ScreenLayoutCanvas.pas:1242` の `UpdateTextEditorBounds`、`ScreenLayoutTextEditOverlay.pas:73/195` の未確定/選択描画、`WindowsImeController.pas:27/48` の編集セッションでのIME退避/復元。参考実装は横組み基準で、縦入力の横線キャレット実装は確認できていない。横線はユーザー要件であり、参照元の完成機能とは扱わない。縦入力への適用は別途設計・検証が必要。参照元は読み取りのみ。

読み取り参照元（MangaMaker と同じ親フォルダーに配置したプロジェクトへの相対パス。同期先に存在するとは限らない）:

- `../MapRaku/Source/ToolPalette/MapRakuToolPalette.pas`
- `../MapRaku/Source/Shell/Toolbars/MapRakuLineStyleControls.pas`
- `../MapRaku/Source/ObjectProperties/Filters/MapRakuFilterFrame.pas`
- `../SYNC_ScreenLayout/ScreenDesignMaker.dpr`
- `../SYNC_ScreenLayout/Source/Editor/Interaction/Text/ScreenLayoutTextEditing.pas`
- `../SYNC_ScreenLayout/Source/Editor/ScreenLayoutCanvas.pas`
- `../SYNC_ScreenLayout/Source/Rendering/ScreenLayoutTextEditOverlay.pas`
- `../SYNC_ScreenLayout/Lib/InputMethod/WindowsImeController.pas`

## β版の保存形式

最新ユーザー方針: β版なので旧版互換性を重視しない。仕様整理と実装を優先し、移行機能を追加しない。既存のv1読込は残す。現在のデータの意図しない破損防止、無効形拒否、保存/Undo整合は維持する。

現行版はJSON version 1/2を読む。多角形のない作品はv1、多角形追加/四角の頂点編集/4点分割後の保存はv2。多角形を共通登録した`Presets/Layouts.json`もv2になり、旧実行ファイルはv2非対応。

試用前にデータ保存先全体（作品UIDフォルダー、共有`Presets/Layouts.json`、`Characters/`）を別フォルダーへコピーし、別の試用コピーへ`MANGAMAKER_DATA_ROOT`を向ける。元作品と保管用バックアップを上書きしない。手順と通常操作は [README.md](README.md) に集約する。

## 作業環境と保護

以下はクローン前の作業記録。調査当時は対象/確認した上位にAGENTS.mdやGit管理情報はなく、既存ソースを `TestOutput` 内へ退避した。当時のユーザー指示はGitHub同期向けの説明整備であり、commit/push依頼ではなかった。

自己検証は正規Delphi Win64コンパイラとMSBuildを使い、IDEを起動せず、出力/仮データを `TestOutput` に隔離。外部送信/画像生成/音/実作品変更/ユーザーアプリ強制終了/配備/commit/pushは行わない。プロジェクト直下exeに他経路の更新を観測したため、古い退避版を直下へ戻さない。検証用exeは常にTestOutput内のものを使う。

保護確認の証拠範囲: 元exe退避はSHA-256 `DE17EF8891D8C529DEC1676E4C92F07E47AC686D8AE22FAB3F8A2B7B398F1C09`のまま保持。直下exeは04:51 UTCの更新後`49F7691A7A6A7110F060AED881472F2801BF19EA88C2303D7BA527549048920A`で、幾何作業中の観測と一致する。直下resは初回から`7BC4027648FFFA75E90A690010B68E09FE95A632F2E0DA1BA019CE0C5F975167`。MapRakuは記録した14ファイルのみを比較して一致を確認した。

通常保存先`Documents/MangaMaker`は読み取り確認時点で存在せず、実作品の事前ハッシュ一覧も取得していない。実作品の無変更を事前/事後ハッシュ照合で証明したとは扱わない。検証は専用のDataフォルダーのみを使用した。別の保存先の実作品についても包括的な照合はしていない。

## ローカルクローンの設定（2026-10-13）

ユーザーの依頼により `https://github.com/vramwiz/MangaMaker.git` を `D:\DelphiProg\MangaMaker` へクローンした。`main` は `origin/main` を追跡する。投稿者は既存の同階層リポジトリと同じ `vramwiz <vramwiz@gmail.com>` を、このリポジトリ内の Git 設定へ登録した。

`remote.pushDefault=origin`、`push.default=simple`、`push.autoSetupRemote=true` をローカル設定した。既存の Git Credential Manager を使用し、`git push --dry-run origin main` は成功した。今回の設定確認では実際の commit/push は行っていない。

参照先は同階層の `../MapRaku/` と `../SYNC_ScreenLayout/` で実在を確認し、旧環境の ScreenDesignMaker パスを上記の相対パスへ修正した。開発時の参照方針は `AGENTS.md`、利用手順は `README.md` に記載した。

今回のクローンでの検証: 参照ファイル8件の実在と `git diff --check` は成功。`./build.ps1 -SelfTest -OutputDirectory 'TestOutput/CloneVerification'` の Win64 Debug ビルドは成功したが、自己検証は `polygon resize undo restores outline bounds` で停止した。結果は `TestOutput/5333de517b1f44a2aaaa3ca177eb7047/result.txt`。上記の過去記録の360項目PASSは、この環境で再現できたとは扱わない。アプリのソース、プロジェクト定義、res、ビルドスクリプトには変更がないことを確認した。この自己検証の原因調査・修正は今回のクローン/Git設定には含めていない。
