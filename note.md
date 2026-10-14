# MangaMaker 作業記録

## 上部ツールバーをメニューへ統合（2026-10-14）

- 開始時main/0895492096ea89a7254bb701b5f2f34ec8de87d3。前回の画像生成/Debug計測とユーザー試用の未コミット変更を保持。今回変更した既存ソースはMainFormだけで、キャッシュ高速化や描画ライブラリ移行は行っていない。
- 上部8操作を棚卸し：新規/開く/保存/PNGはファイル、Undo/Redoは編集、キャラクター/画像は設定・管理に既存入口があったため、重複する64px相当のバーを廃止。保存/出力/画像/履歴のEnabledをメニューへ同期し、表示メニューには5画面の排他的チェックと次/前/全体表示を追加。右側ツール・選択色・画面名・ステータスを保持。
- 既存Ctrl+N/O/S/Z/Y、Ctrl+1～5、Ctrl+Tab/Shift+Tab、Ctrl+0とテンキー0を維持。PNG Ctrl+E、キャラCtrl+Shift+C、画像Ctrl+Shift+Iを追加してメニューへ表示。選択キーはAltや余分な修飾との組合せで誤発火しないようにし、キャンバスCtrl+A/Delete/Escとホイール/パンも維持。
- VCLのIsShortCutはOnKeyDownより先にメニューを呼ぶため、両入口でガード。通常/汎用テキスト欄・編集可能コンボ・未確定IME、Application.ModalLevel、別のActiveForm、VCL Enabledと実HWND無効状態を確認する。入力欄にはFalse/未消費で返し、その欄のUndo・文字削除・確定取消を保持。明示的なメニュークリックは通常操作として許可する。
- 最終Debug/Releaseとも1752 PASS、CLI4 PASS、追加メニュー検証156 PASS、実メニュー経由のファイル選択/保存/6枚PNG/履歴42 PASS、既存表示操作111 PASS、画像連携73 PASS。Debug11874行/Release11662行、エラー/警告/ヒントなし。Releaseは計測識別文字列/DCU/実行時性能ログなしを再確認する。96/144 PPIの実VCL画面でバーの跡がなく、右ツールと選択表示を確認。
- 最初の追加テストは非表示タブの文字欄へフォーカスしようとして失敗し、表示する吹き出しタブを選ぶよう修正。次のローカルUndo検証には通常のWin32キー変換と同じWM_CHAR(26)も送る必要があり、キー列を修正して成功した。製品ガードや期待値を弱めていない。初期の追加DPIテストは実際に96のままだったため、Scaledを有効にしてから倍率を適用し、CurrentPPI/PixelsPerInchが96/144と一致することを明示的に検証。新3ショートカットは実Win32キャプチャ中に実管理/出力ダイアログを開き、未確定編集の取消とSnapshot/Undo/Redo/キャプチャの保持も確認した。
- 初回全体回帰は、バー撤去でfit倍率が変わり、重複頂点へ動かすテストの整数画面座標に丸め誤差が出て失敗。独立した幾何fixtureを正確な1/4倍率に固定し、実際に完全重複を入力する条件へ修正。製品の形状判定とSnapshot/Undo不変の期待値は維持した。失敗記録もChecks-Debug/とBefore-quarter-scale-test.pasへ保持。
- ユーザー編集のサンプルProject/Data/SourceImages52ファイルをBefore-sample-hashes.csvで保護。既存ZIPの作品を保ち、EXE/README/Summaryだけ更新する。通常EXE/同梱/ZIPは同じ最終Releaseへ同期、直前のEXE/ZIP/文書はBefore-artifactsへ退避。ユーザー稼働アプリの強制終了、音、commit/push、追加清掃は行わない。
- 証跡：TestOutput/MenuUI-20261014-0400/ のChecks-Final-Debug/、Checks-Final-Release/、Menus-run-4/（156件と96/144PPI画像）、OpenUI-run-1/、Native-run-1/、Fake-run-1/、CLI-final-build/、Final-verification.json、Reproduction/。実IME候補/物理DPI・物理キー/長時間制作の未検証範囲は継続。

## 画像生成連携の仕上げ・Debug性能計測（2026-10-14）

- 開始基準はmain / 0895492096ea89a7254bb701b5f2f34ec8de87d3。キャラ/画像管理の「Codexで画像生成」→専用app-server→正式imageGeneration/turn完了→画像検証/管理先コピー→既存登録/プレビュー更新を接続した。UIは非同期・生成中の無効化・実段階・取消・開始要求30秒/生成10分の制限を持つ。
- 要求/スレッド/ターン/画像項目と作品/ページ/コマ/素材/管理画面のID、生成条件、参照ファイルを照合。遅延/重複/別要求・条件変更を拒否し、内側の入力画面中の採用は待つ。コピー先を検証して保存成功後に採用し、元生成ファイルと旧画像を保持。プレビューはバックグラウンド復号済みの画像を受け渡す。受信コピー・未採用候補の処理はその要求の所有分だけ。通常の外部register_imageもコピー先検証・元データ保護を強化。
- 実生成1回で9 PASS。元/採用先SHA-256は59149B2C4480402131216CB044387059A36738881C33E6CDA09A7C35BDEDE11Dで一致。UIボタン/表示・タイマー継続・元保持とreceiptのIDを確認。以後は模擬結果を使用し、再生成していない。模擬73 PASSは早期通知/重複/不正画像/誤スレッド・ターン/複数画像/時間超過/停止したstdin/取消/閉じる/ページ切替/保存失敗/警告付き採用/再送/内側モーダルの待機を含む。
- 古い読み取り専用条件による自動承認レビューの拒否は、新しいユーザー指示の証跡を受け、同じDebugビルド/検証コールを1回再試行して許可された（session82706、Checks-Debug-2 exit0/1728 PASS）。接続断で結果不明だったcell79のReleaseビルドも復帰後にログとEXEで完了を確認し、重複実行しなかった。
- ComicPerformanceと全呼出しはDEBUG条件内。固定39カテゴリの件数/合計/最大/50ms以上だけを集計。操作側のロックは待たず欠落件数を記録し、2秒周期の専用スレッドで書く。プロセスごと256KiB×2のJSONLへ循環出力。同じデータ領域全体は4MiB・64ファイルまでで、起動ID付きのファイルを使い、既存ログを削除せず追加を抑止する。ファイルロックで同時起動・Windowsセッション間も調整。本文・プロンプト・画像パスを含めない。Releaseにはユニット/DCU/識別文字列/実行時性能ログがなく、詳細計測追加前後のReleaseはリソース以外の全PEセクションが一致した。
- 最終Debug1728 PASS、Release1728 PASS、CLI4、計測付き画像連携73、従来の表示111/読込42もPASS。早期return/例外の集計、50万回、無効時ログなし、容量/JSON項目/Release除外など性能12チェックPASS。最終ビルドは両構成ともエラー/警告/ヒントなし。全検証用データを残し、追加清掃をしていない。
- 隔離した実VCLで10シナリオを測定。温まった6ページ描画906ms/30描画中、FrameRgn679ms（約75%）、吹き出し770ms。画像探索約4ms/240回、文字配置約30ms/200回で、主因はGDIの縁描画。フォーム再描画平均63ms、空白クリック1.8ms、6ページ保存28ms、80ページ保存252ms。冷えたフィルター再計算は最大305ms。親子時間は重複するため合計しない。サムネイルの毎回再描画と同期SaveDraftも改善候補。高速化・MapRakuライブラリ移行は未実施。
- 試用で変更されたサンプルProject/Data/SourceImagesの現状52ファイルをBefore-final-sample-hashes.csvへ記録し保持。ZIPは既存の配布用作品を維持してEXE/README/Summaryだけ更新する。通常版/同梱版/ZIPは最終Releaseへ同期し、直前のEXE/ZIP/文書はBefore-final-artifactsへ保存。ユーザーJSONを配布用の状態で上書きしない。稼働ユーザーEXEの強制終了・音・push・追加清掃は行わない。
- 証跡はTestOutput/Generation-20261014-0202/。Generation-verification.json、Performance-verification.json、Final-bounded-core-Debug/verification.json、Final-bounded-core-Release/verification.json、CLI-bounded-final/results.json、Fake-run-6/result.txt、Real-run-1/result.txt、Performance-ui-detail/、Final-verification.json、Reproduction/を参照。
- 残りは実IME候補/実変換/他アプリ復帰、物理マウス・実モニターDPI、長時間制作、高度組版等。以下の記録は過去の区切り。

## ホイールズーム・表示パン（2026-10-14 01:18 UTC開始）

- MainFormに保存対象外の表示倍率/オフセット/パン状態を追加。描画、画面→作品座標、ヒット、スナップの表示倍率を共通更新する。描画先の整数幅から実倍率を求め、rendererと入力の倍率を一致させる。ホイールはマウス位置を基準に1段15%、部分デルタにも対応し、フィット比0.1〜16で制限。パンを96PPI基準で保持し、ページ端32px相当を画面内へ残す。Ctrl+0、ページ/作品切替でフィットへ戻す。
- 中央ドラッグは対象の上でも表示パン。左は選択(0)/しっぽ編集(12)/文字配置(13)の空白だけ。コマ/画像/吹き出し/はみ出した文字/しっぽ/素材/8点/頂点/複数選択枠を先に判定する。作成/多角形/分割/読む順番/しっぽ追加とCtrl複数選択は左パンに使わない。3px相当未満の空白クリックは従来の選択解除、ドラッグは選択を保持してパンする。
- パンと編集の押下継続中はホイールを消費して変換を固定。パンのボタン離し/欠落フラグ/喪失/cancel-mode/切替で状態を解除し、Escは開始位置へ戻す。TComicViewが実capture喪失を通知。Canvasの自動csCaptureMouseを外し既存編集/パンで明示管理して、VCLのMouseUp前の自動解放が編集を取消す問題を避ける。他の自前コントロールへcaptureを移した時に奪い返さない。
- 既存回帰を弱めず、初回描画前の過小な仮表示倍率計算、空白クリックと選択解除の競合、1px移動のSingle丸めで閾値未達になる点を修正。移動開始は押下時の整数画面座標で判定する。検証の頂点位置は対象Probe自身から計算。未使用代入ヒントも整理。
- Debug/Release各1728 PASS（既存1632＋表示96）、10483行、エラー/警告/ヒントなし。CLI4件はexit2/生成0件。実VCL 96/144PPIの描画/ヒット/スナップ、全8点、画像/文字/しっぽ/素材、作成点保持、data/Undo/Redo/dirty保持、Esc/離し/喪失/ページ・作品切替を検証。Native-run-5は同じ96件＋実Win32 capture15件=111 PASS。OpenUI-run-1は読込/保存/PNG/履歴42 PASS。
- 大きい画像6ページの既存PNG性能検証が今回の同時実行環境で240秒待ちを超えたため、プロセスを強制終了せず完了まで待って結果を回収。完走記録はChecks-Debug-6/とChecks-Release-1/。仮データと中間ファイルは今回のセッション内だけ整理し、最終結果・小さい画面画像・ソース・旧EXE/ZIPのバックアップを保持。
- 通常EXE、サンプル同梱EXE、ZIPを同じ最終Releaseに同期。既存のProject/Data/SourceImages52ファイルと、MainForm以外の既存ソースをハッシュ照合して保持。通常履歴へ追加変更しない。実ユーザー作品・人物ライブラリ・Git履歴を変更せず、音や強制終了も行っていない。
- 物理GUIツールはplatformディレクトリ不足(HRESULT 0x80070003)で初期化できなかった。自前VCL画面の描画画像を目視し、所有するウィンドウへのメッセージと実captureで代替検証。物理マウス、実IME、実モニターDPIは未検証。
- 全証跡: TestOutput/Viewport-20261014-0118/。NativeViewportChecks.dpr、run-native-viewport.ps1、Native-result.txt、OpenUI-result.txt、各Checks、Final-verification.jsonを参照。


## サンプル読込UIと履歴の修正（2026-10-14 00:25 UTC開始）

- 原因: Open/Recentの人物前提が既存作品の読込をキャラ管理へ迂回させ、解除してもPaint/タブ/編集/保存条件が作品を隠していた。同梱版の初期フォルダーもData/Projectsで、実サンプルProjectへ到達しづらかった。VCLのダークスタイルshDialogsがクラシック共通画面を選んでいた。
- ComicProjectDialogを追加。標準Windowsファイル選択をこの操作だけ使い、スタイルのSystemHooksはfinallyで復元。Project.jsonを明示し、既存作品・同梱サンプル・通常データの順に初期位置を決め、IFileDialog.SetFolderで実際の初期位置を設定。取消時にカレントディレクトリを保持。
- Open/Recentは人物未登録でも読める。既存作品がある場合はページ表示・タブ・基本編集・保存を許可。NeedProjectを作品の有無判定へ限定し、PNG出力も一貫して許可。NewProject、共有人物を使うImages、素材の追加・共有ライブラリ・bridgeの人物前提は保持。既存ユーザーデータをコピーで上書きしない。
- Debug/Releaseとも1632 PASS、10209行、エラー/警告/ヒントなし。CLI4件はexit2/生成0件。Native-run-7の追加42 PASSでは実Windowsファイル選択をOpenボタンから開き、取消/選択/再試行/不正JSON、6ページ表示、編集/Undo、保存/再読込、実ShowModal出力確認と6枚PNG、通常履歴のメニュー操作を検証。失敗した前段の検証をPASSとは扱わず、最終の完了結果をNative-result.txtに保存。
- 通常データルートD:\Users\take6\MangaMakerのPresets/RecentProjects.jsonへTComicRecentProjects.Rememberでサンプルを登録。開始時0件→1件。ユーザーの人物/プリセットを変更せず、メニューから実サンプル6ページを開く検証だけを隔離設定で実施。ZIPにはPC固有履歴を含めない。
- 直下MangaMaker.exeとサンプルApp/MangaMaker.exeを最終Releaseへ配備。既存EXEとZIPはBeforeに退避。サンプルProject/Data/SourceImagesの52ファイルは前回ハッシュを保持。サンプルZIPも更新。commit/push/checkout、実作品の編集、ユーザーアプリの起動や強制終了、音の再生は行っていない。
- Windows物理GUIツールは初期化時に必要なplatformディレクトリを見つけられず使用できなかった（HRESULT 0x80070003）。許可された代替としてテスト自身のVCL/COM画面を操作。ファイル選択画面のPrintWindowは黒画像になるため、その画面の物理的な見た目は未確認。編集画面の実VCLキャプチャは確認済み。実IME候補と実モニターDPIは引き続き未検証。
- 途中の人物前提一括解除は自動承認レビューが範囲過大として拒否し未実行。表示/保存/出力の限定修正で代替し承認された。生成・共有アセットの前提を保持している。
- 全証跡はTestOutput/OpenUI-20261014-0025。NativeOpenChecks.dprと実行手順、Native-result.txt、Checks-Debug-1/、Checks-Release-1/、CLI-final/、Final-verification.jsonを参照。


## コマ全体スナップ・1段階出力確認（2026-10-14 JST / 2026-10-13 23:00 UTC開始）

作業先は `D:\DelphiProg\MyApp\MangaMaker`。開始時は `main` / HEAD `cb272bc5319d6400a1368538b89c57d91ebb15cc`、未コミット7ファイル・吹き出し輪郭1390 PASSの状態を既存成果として引き継いだ。開始時差分とソースは `TestOutput/Snap-20261014-2300/Before/` および `Before-user-changes.patch` に退避。commit/push/checkoutは行っていない。

- 仕様9.2/9.3: 単体・複数選択のコマ全体の移動と外側8点拡縮へスナップを追加。ページ基準の外枠、静止した他コマの辺/頂点の水平垂直位置、近隣コマから測った縦横間隔を利用。移動は範囲を平行移動してサイズを保持し、拡縮は動かす辺だけを変更して反対側を固定する。選択中の全コマを候補と間隔計測から除外する。距離・同距離の優先順位を固定し、順序反転で結果が変わらない。
- Alt/設定OFF、最小コマ寸法、外枠を超える自由配置、混在形状の原子的な変形拒否、取消・1回のUndo/Redoを維持。ポインター更新は開始時の形状から計算して吸着量を累積しない。元位置へ吸着して変更がない場合はUndoを増やさない。画像配置、吹き出し、素材、頂点編集の動作は既存経路を維持する。
- 仕様14: 未配置/参照切れの別警告ダイアログを、出力対象を選ぶ1つの確認画面へ統合。全ページの未配置/参照切れと同一画像の2回目以降の配置数を表示し、注意があっても変更のみ/全ページ出力を選べる。取消は作品/Undoを保持。長い出力先は読み取り専用欄で選択・コピー、全文ヒント表示が可能。
- **Win64 Debug/Releaseとも1632 PASS、10134行、警告・エラー・ヒントなし。CLIガードは各構成2件PASS（exit2、生成0件）。** 1390から242件増加。スナップ162件と出力確認80件の回帰を追加した。全8点、単体/複数、非選択コマ保持、開始座標/反対辺、Alt/設定OFF、保存再読込、Undo/Redo/取消、96/144 PPIのVCLイベント、出力確認の実ShowModal開閉、長いパスの保持・選択を確認。
- 最終結果: `Checks-Debug-7/` と `Checks-Release-2/`。ビルドログは `Debug-build.log` / `Release-build.log`、CLIは `CLI-final/results.json`。いずれもこのセッション内。最終EXEは `Debug/MangaMaker.exe` / `Release/MangaMaker.exe`。開始前の `TestOutput/Verified/` / `Verified-Release/` と直下EXEは上書きしていない。
- 96/144 PPIのスナップ画面と出力確認（注意なし/未配置のみ/未配置＋重複）の6画面を保存し目視確認。これは隔離したVCLスケーリング・イベント・ダイアログの確認であり、実モニターDPI切替や物理キー/クリック、実IME候補操作ではない。
- スナップ計算を20/100/480コマ、単体/半数/全選択、各100更新で小さく計測。480コマは平均2.416～5.153ms/更新。このPCのコンソール計測で、実制作全体の応答時間を保証する値ではない。`Benchmark/performance.csv` に記録。
- 準備の停止は、作業ディレクトリが違う外部PowerShellクライアントと、実行中のprogress.txtを読むことによる共有違反だった。プロジェクトcwdで実行し、ログは終了後に読むようにした。混在図形の幅450pxに生じた0.000031px差も、回帰の完全一致を0.001px許容へ修正した。製品の座標を丸めて変更する対処はしていない。全試行の短い結果は `All-verification-attempts.json`。
- 既存の輪郭サンプル/検証画像を今回専用 `SampleData/` へコピーして再利用し、コマ・出力確認作品を追加。人物参照と3コマの画像を同じ既存BMPで保持し、1コマは未配置とする。2作品を実モデルで読み込み検証し、`snap-sample.png` をオフスクリーン描画。元の5ファイルのハッシュは維持。画像生成や実作品への変更はしていない。起動と操作は `Sample.txt`。
- fixtureは結果/画面を退避後に今回の各Runフォルダーだけを逐次削除。今回生成の累計fixture約1.03GB、最大1回176,515,785B。今回のDCU/RSM・計測EXE・中間確認記録も整理し、最終2 EXE・小ログ/画面・開始時退避・サンプルは終了時約32.9MiB（検証セッション分、永続サンプルとZIPは別）。開始D空き11,635,245,056B、終了計測11,041,013,760B。D全体の空きと今回フォルダーの残量は別々に記録する。詳細は `Cleanup.json` と終了計測の `Final-verification.json`。
- 作業中に未追跡の `Codex連携_画像生成と受信の使い方.md` を観測した。今回こちらが作った変更には含めず、そのまま保持する。他プロジェクトや開始前のfixture、ユーザー素材は清掃対象外。

残り: 実IME候補/変換・他アプリ復帰、実モニターDPI切替、長時間制作。実装候補はルビ/高度な組版、より高度なフィルター、楕円/角丸/凹多角形の帯分割。多角形の斜辺間隔推定と厳密な等間隔配置は未実装。縦入力の横線キャレットとScreenDesignMaker由来の既存入力/描画実装は変更していない。以下の1390/1262/360等は各段階の過去記録として読む。

### 追加依頼：1作品の機能サンプル（23:36 UTC以降）

新規機能追加を止め、永続フォルダー `Samples/FeatureTour-20261014/` に自己完結した6ページ作品を作成。開くファイルは **`D:\DelphiProg\MyApp\MangaMaker\Samples\FeatureTour-20261014\Project\Project.json`**。各ページの目的とスナップ/Undo/管理/出力の試し方は同フォルダーの `README.md`。`Start-Sample.bat` は同梱の最終Release EXEを専用Dataで通常起動する。

四角/楕円/角丸/多角形・実際の幾何処理による斜め分割・画像配置、基本3形状×4輪郭の12吹き出し・複数三角/思考しっぽ、縦横文字と装飾/文字配置/文字だけ表示、3透明素材・4フィルター・3枠・複数素材、人物/服装2状態・背景/子/別位置/タイトル、2コマ割りテンプレート・ページ基準・生成指示/作品スナップショット・フォント履歴を保存した。6ページ目は未配置画像1コマを意図的に残し、出力注意を試せる。

仮画像は小さいローカル図形BMPと組込PNG。人物/プリセットはサンプル専用Data、作品画像/効果はProject内の相対参照。JSONに外部絶対パスがないことと全参照ファイルを確認。通常の共有ライブラリ/既存作品は使用しない。AI生成・通信は未実行。

検証ユーティリティは現行MainFormの一時コピーでprivateの可視性だけをpublicへ変え、製品ソースの実装は変更せず `SaveProject` / `OpenProjectFile` を呼んだ。保存前後/出力後の正式再読込が一致、6枚PNG出力・未変更0枚再描画を確認。思考しっぽ位置を見やすく修正し2枚だけ差分再描画。実VCLの4ページと人物/背景/生成/ページ/出力確認を非表示で撮影し、PNG6枚を目視確認。手動操作・実IME・物理DPI・長時間運用や、未実装の高度組版はサンプルの対象外。検証の詳細はサンプル内 `Verification.txt` / `Refine-verification.txt` / `Capture-verification.txt` / `Summary.json`。

## 再開・吹き出し輪郭（2026-10-14）

現行作業先は `D:\DelphiProg\MyApp\MangaMaker`。開始時は `main` / HEAD `cb272bc`、未コミット変更なし。ユーザー指示は作業再開、サンプル画像の利用可、画像の繰り返し生成を避けて使い回し、不要ファイルを都度削除すること。今回の追加は以下。commit/pushは実施していない。

- 基本形状とは別に `TComicBalloonContour`（通常／ギザギザ／波線／雲形）を追加。右側の「本体の輪郭」と「文字・設定を反映」で選択中へ適用し、新規作成にも現在の設定を使う。
- `BalloonBodyRegion` でページ座標から輪郭を作り、描画・選択判定・しっぽ根元判定で共有。既存のしっぽ合成、塗り・縁、透明、枠外表示を使用し、輪郭変更では文字配置やしっぽの座標を変えない。輪郭の数・深さは固定。Renderer署名は `renderer-12`。既存PNGキャッシュは次回に一度再描画する。
- 保存はversion3のまま `contour` を追加。省略した既存データは通常輪郭とし、不正な種類・型・小数を拒否する。
- **Win64 Debug/Releaseとも1390 PASS、9748行、警告・エラー・ヒントなし**。3基本形状×3輪郭の保存再読込、1操作Undo/Redo、原点をずらしたDCの全画素比較、しっぽ接続部、選択/根元判定、枠外/クリップ/透明、96/144 PPIのVCLイベントによる変形・取消と設定欄への到達、差分PNG/出力後Undoを追加した。
- 準備時のDebugも1262 PASS。60秒のスクリプト制限後も本体が動作し約104秒で正常終了したため、自己検証待ち時間を180秒へ変更。現在の指定検証コマンドは成功する。
- 開発途中のDC比較FAILは検証のScanLine添字を上下逆に扱った誤りだった。VCL `Vcl.Graphics.pas` の `TBitmap.GetScanLine` を読み取り確認し、添字を修正。製品の描画座標を変更せず再検証で一致した。
- 証跡を `TestOutput/Resume-20261014/` に集約。`Debug-result.txt` / `Release-result.txt`、各performance、使用ソース/実行ファイルのハッシュを保持。実行ファイルは `TestOutput/Verified/MangaMaker.exe` と `TestOutput/Verified-Release/MangaMaker.exe`。
- 同じ既存テスト画像1種類を再利用し、`balloon-contours.png` に9種類の見本を出力して目視確認。編集可能な作品と有効なキャラ参照だけを `SampleData/` へ残す。起動方法は同セッションの `Sample.txt`。AI画像生成は行っていない。
- 今回作った準備/失敗/成功fixtureの大量画像・一時作品は、結果とサンプルの退避後に削除済み。セッション内に残したサンプルと記録は合計約2.6MiB。開始前から存在した過去fixtureや他プロジェクト、実作品は整理対象外。
- 現配置では `../MapRaku/` は存在し `../SYNC_ScreenLayout/` は不在。現行ソースは独立してビルド可能で、他プロジェクトは変更していない。

次候補はコマ全体の移動・拡縮スナップ、さらに高度な組版。実IME候補/変換、実モニターDPI切替、長時間制作は引き続き未検証。以下は過去の記録として読む。

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

### 公開確認

- 実装commit [`0e8e602ea9d07ab2ad1107387c171851fde68b98`](https://github.com/vramwiz/MangaMaker/commit/0e8e602ea9d07ab2ad1107387c171851fde68b98) を既存の `origin/main` へ通常push。14:51 UTCに `git ls-remote` とfetchで、remote/main・HEAD・origin/mainの一致と作業ツリーがクリーンであることを確認。force pushなし、Git認証のブロックなし。
- GitHubの当該commitを確認した結果、Actions実行0件、statusチェック0件、Check Runs 0件。このcheckoutにもActions定義はなく、利用可能なCI結果はない。CI成功として扱わず、上記のローカルDebug/Release/CLI検証を根拠とする。証跡はsession内 `Git-publication.json` / `GitHub-check-runs.json` とCI集約記録。
- 後続はこの公開記録だけの文書更新。実装・ビルド入力・検証済みexeは変更しない。同期対象はソース/文書だけで、生成物と大きな素材はリポジトリへ送っていない。
- 最後の保存経路確認では、パイプ登録のPersistがDraft単独のAtomicWriteであることを確認。ページ別保存失敗と混同した一時的なテストは誤った期待値で失敗したため取り除いた（ログ `Draft-publication-reproduction.log`）。製品修正はなく、全ビルド入力のハッシュは確定済み1262候補と一致。上書きされたDebug exeは再ビルド・1262 PASSへ揃えた。最終Debug fixtureは `TestOutput/5fdcd5419111458a9797d892464ce590/`、Releaseは `TestOutput/1614473244ca489d8e0bf336deb3b82e/`。以後は完了確認だけを行う。
- 15:06 UTC時点のD空きは約227MiB。最終exeは `TestOutput/Verified/MangaMaker.exe`（Debug）と `TestOutput/Verified-Release/MangaMaker.exe`（Release）。資料の候補ハッシュと最終検証ハッシュを再同期して、この文書更新も通常pushする。

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
