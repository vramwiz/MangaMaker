## 作品作成・上位3画面・作品内相対参照（2026-10-19）

- 今回までの検討を実装。上部をページ編集／画像管理／キャラ管理の順に分け、右側はページ編集の5モードに限定した。旧Ctrl+6とCtrl+Shift+Iは上位の画像管理へ接続する。共通キャラ管理も非モーダルで埋込み、作品未作成でも設定メニューから利用できる。作品作成・読込後はページ編集を初期表示する。ページ編集の選択・表示位置・倍率・モードは上位切替で初期化せず、管理側の選択IDを保持し入力を保存してから移動する。保存失敗では画面を破棄しない。
- 新規作品をDialogs/Project/ComicNewProjectDialogへ分離。保存先は初期値空の必須入力で、作品名・任意の話数・任意の貼付台本・用紙幅高さと4余白(px)・プリセット選択をまとめた。プリセット適用後の数値変更も可能。指定先そのものを使い、作品名由来のフォルダやUID階層を作らない。既存フォルダへの上書きはユーザー判断とする。台本・キャラ・画像なしでも空の1ページから開始し、保存先の作成失敗時は入力を保って再指定できる。
- Model/Storage/ComicProjectCreationが入力検証と保存を担当。現在は全ページ共通の用紙を使用し、TComicPageに未使用時は共通を継承するHasOwnBasis/OwnBasisと任意pageBasis保存領域を準備した。ページごとの用紙操作・描画はまだ有効化していない。
- キャラ必須条件を新規作成、画像管理、ページ削除・並替・テンプレート、配置、素材配置、ローカル連携の画像登録から除去。画像未登録でのコマ割り・吹き出し作成も可能にした。背景だけの画像生成コンテキストに人物参照を要求しない。選択した人物参照そのものの欠損は従来どおり検出する。
- TComicAsset.relativePathを新参照、fileを旧参照とする。ImageFile/ImagePathへ参照解決を集約し、新参照が空のときだけ旧参照を使う。新参照の実体欠損で旧画像へ戻さない。新参照は相対パスとして読み込み、SafeChildで作品外参照を拒否する。新しい登録・画像採用・生成採用・一覧・台本の取得判定を同じ優先順位へ統一した。
- プロジェクトファイルの実際の読込位置をFolderに使う。Project.json／Draft.json／Script.txt／Page-ID.json／画像／効果コピー／連番PNG／出力キャッシュは指定先の直下。使用する共通人物の画像・情報はModel/Storage/ComicProjectReferencesでReferencesへ固定し、JSONのcharacterReferencesへ保存する。共通ライブラリを更新しても既存の作品内参照は自動更新しない。コピー先で共通ライブラリがなくても、生成コンテキストと人物選択に作品内参照を使用する。
- 台本は新規フォームか後からの貼付フォームで初回読込する。既存台本の追加・再読込・置換はメニュー操作で保留。内部の従来の補完処理は残す。空の初期ページを自動コマ配置で埋めない。
- 最新の最小検証方針に従い、MANGAMAKER_SELFTEST_SCOPE=project-workflowを用意して今回の31項目だけを自己検証した。指定のbuild.ps1 -SelfTest -OutputDirectory TestOutput/Verifiedをこのスコープで実行しPASS。fixtureはTestOutput/6e512d085b934896874c25b604dbb6d9。新規作成・任意台本・人物なし生成準備・外部登録のローカル模擬・3画面切替・PNG出力・新旧優先・フォルダコピー後の読書き・共通画像削除後のローカル人物参照を確認。初回は任意pageBasisの取得が例外になり、nil既定値を明示して修正した。全回帰・DPI往復・物理IME・実画像生成・外部送信は未実施。旧UIと旧ディレクトリ配置を前提とした全回帰は今回の検証基準にしていない。
- 通常Win64 Releaseビルド成功。94ユニットの構成、UTF-8 BOM、git diff --checkを確認。既存ComicPlacementPreviewのH2077以外にエラー・警告なし。通常版に検証・計測DCUなし。新規フォームと3画面の隔離VCL描画を目視確認した。ログ・ハッシュ・結果はTestOutput/ProjectWorkflowへ記録。開始前の全Source・プロジェクト・文書・EXE・res・Git差分はBeforeへ保持している。作業中にユーザー側の既存変更がd03e1c9へ記録された状態を観測したが、こちらからcommitやresetはしていない。
- 通常アプリが起動していないことと開始前EXEの一致を確認し、直下MangaMaker.exeを通常Releaseへ更新。SHA-256：FF72A94A30023FADCDEB55C36ABA71830EB4FFB5647215EE1CD2FE1E66D7F469。resは開始前とバイト一致へ復元した。実作品・共有設定・他プロジェクトの検証用変更、ユーザーアプリの自動起動・強制終了、commit/pushなし。

## UI境界の細い縁と検証方針（2026-10-19）

- 最新ユーザー指示：以降、追加指示があるまではDPIなどの検証を最小限とする。軽微なUI変更で多段階DPI往復や全自己検証を毎回繰り返さず、変更に必要なビルド・差分確認を優先する。
- ページ一覧・操作見出し・右側設定・モード切替・画像管理の一覧／プレビュー／操作バー・素材パネルへ、BevelWidth=1の細い縁を追加した。既存のアイコンボタンの1px枠は保持。外側の寸法と操作配置を維持し、枠の内側だけ1px分を使う。
- 今回は通常Win64 Releaseビルド、89ユニットの構成確認、差分・BOM確認に限定。DPI往復・全自己検証・実UI操作は未実施。既存の画像管理の寸法検証は、外幅250DIPと枠を差し引いた一覧幅を分けるよう更新したが、今回は実行していない。既存ComicPlacementPreviewのH2077以外にビルドエラー・警告なし。
- TestOutput/UIBorders/Beforeへ変更前の対象ソース・文書・EXE・res・既存Git差分を保持。build.logは同セッション内。通常アプリが起動しておらず、開始前EXEの一致を確認して直下EXEを更新した。SHA-256：18E01AC0CE6088280AF415F1ECCB2CB21ED6C79AB4D89706AA1512F90CD6B0A9。resは開始前へ復元。自動起動・実作品変更・commit/pushなし。

## 作品を開くまで編集UIを非表示（2026-10-19）

- 初期起動ではメニューだけを残し、ページ一覧の親パネル・編集領域全体・ステータス欄を非表示にした。構築時も非表示にして起動中の露出を防ぐ。共通管理と新規作成・開く・最近使った作品のメニューは維持する。
- RefreshUIで作品の有無へ表示を同期する。新規作品や読込をAdoptProjectで確定した後に表示するため、取消・読込失敗で未作成の編集画面は開かない。既存の画像管理モード内の表示切替は保持する。
- 自己検証へ起動時非表示・メニュー維持・新規採用後表示・初回読込失敗時非表示・読込成功後表示の5項目を追加。Win64 Debug/Releaseとも4888項目PASS（末尾の完了報告行を除く）。両build.ps1の180秒待機は超過したが、検証プロセスは完走し、停止後のresult.txtで失敗なしと完了報告を確認した。fixtureはDebugがTestOutput/9f67c136c42847d090476f33d2a39d1e、ReleaseがTestOutput/e1e5afda21694554815f90db88a7ce99。非表示フォームの状態確認であり、通常起動の手操作確認とは区別する。
- 通常Releaseもビルド成功。89ユニットの構成制約、PascalのUTF-8 BOM、git diff --checkを確認。既存ComicPlacementPreviewのH2077以外にエラー・警告なし。通常版の検証・計測DCUは0件。ログ・ソースハッシュ・結果はTestOutput/StartupUIへ記録し、開始前Source・EXE・res・文書・既存差分をBeforeへ保持した。
- 通常アプリが起動しておらず開始前EXEの一致を確認して直下MangaMaker.exeを更新。SHA-256：38CD58B193CBF91FA1DE0643D7BF8E886E892CF63A3A904C407837ECDD399244。resは開始前とバイト一致へ復元。実作品・他プロジェクトの変更、自動起動、実画像生成、外部送信、commit/pushなし。

# MangaMaker 作業記録
## セリフ本文欄の非表示と右側設定の簡素化（2026-10-19）

- ユーザー指示：セリフ本文はページ上の入力操作で十分なため、右側の本文表示・編集は不要。ただし将来に備えて処理を残し、非表示にする。右側はスクロールしなくても使える簡素さを優先する。
- ComicWorkspaceUIの本文TMemoと「専用文字入力」ボタンをVisible=False・TabStop=Falseへ変更した。本文の同期、即時反映、同一フォーカス中のUndo集約、専用入力画面とその確定・取消の処理は保持する。ページ上の直接入力・再編集・文字選択、台本セリフ取込も維持する。
- 設定を台本取込／フォント／文字サイズと縦横・文字のみ／装飾4種／文字色と輪郭／線幅と塗り・線色／枠外表示／削除へ短い行で整理した。本文欄を隠した後の空白も除去し、必要な縦寸法を748DIPから422DIPへ短縮した。通常の画面では下端の削除まで収まり、極端に小さい画面用のスクロール機構は保持する。製品ソースの今回変更はWorkspace/ComicWorkspaceUIのみ。
- 既存のUI回帰へ、通常・狭いウィンドウ×96/144 PPIでスクロール位置0のまま全表示設定・削除が収まること、旧入力欄が非表示でTab対象外なことを追加した。非表示のコントロールは配置重複の判定から外し、保持機能のEsc・ショートカット保護・メモ即時反映・Undoは検証中だけ旧欄を表示して従来の確認を継続する。ページ上の文字入力の回帰も維持した。
- Win64 Debug/Releaseは各4883項目PASS（従来4763から120項目追加、末尾の完了報告行を除く）。両build.ps1は180秒以内に完了。Debug fixtureはTestOutput/f58f4388400b495c9ab3af04add1e0f8、ReleaseはTestOutput/2a744a63fd9c4292887aa7a32c24ddd6。通常Releaseも成功し、検証・計測DCUは0件。既存ComicPlacementPreviewのH2077ヒント以外にエラー・警告なし。構成89ユニット、対象PascalのUTF-8 BOM、git diff --checkを確認した。
- ui-96/144-mode3-compact.pngとui-96/144-narrow-mode3-compact.pngを出力し、狭い96/144 PPIの実VCL描画画像で本文欄がなく、設定・削除が下端まで収まることを目視確認した。これは隔離VCLによる確認で、実モニターDPI切替や物理IME操作の再試験はしていない。ログ・ソースハッシュ・検証結果はTestOutput/CompactDialogue/のdebug.log、release.log、production.log、source-hashes.csv、verification.jsonへ保存した。
- 開始前のSource・dproj/res・通常EXE・README/noteと既存Git差分はTestOutput/CompactDialogue/Beforeへ保持し、以前の未コミット変更を維持した。実作品・共有設定・同階層プロジェクトを検証用に変更せず、今回の読み取り参照はリポジトリ内のみ。
- 通常アプリが起動しておらず、直下EXEが開始前と一致することを確認して通常Releaseへ更新した。SHA-256：3CD8E0BC355E4EFE63FE24954958E99DCE5406037C8CBBFF1662D73F3CE2076F。旧EXEはBeforeへ保持し、resは開始前とバイト一致へ復元した。アプリの自動起動・強制終了、実画像生成・外部送信、commit/pushなし。

## 画像管理の常設化・IME終了経路・DPI V2（2026-10-19）

- ユーザーから実IME操作の動作確認を受領。ただし経路によってIMEがオフにならないとの指摘があり、文字入力から非入力操作へ移る境界を修正した。Text/ComicImeFocusで文字欄・編集可能コンボを除外し、メインフォーム、画像管理、専用文字入力のCM_FOCUSCHANGEDでIMEを閉じる。既存の変換結果受取や入力バッファ、WindowsImeControllerの退避・復元は維持する。実IME入力そのものの未検証扱いは取り下げるが、今回修正した各終了経路の物理操作は未確認。
- 画像管理を第6の編集画面へ移動。切替アイコンは一番左に重ね画像の図柄で表示し、Ctrl+6と既存Ctrl+Shift+Iからも開く。既存Ctrl+1～5の割当は保持する。画像管理では通常の編集領域へ一覧・プレビュー・説明・参照人物・生成・台本取込を埋め込み、その他の編集時は従来の右側ツール欄へ戻す。キャラクター管理や画像のファイル選択等の個別操作は従来どおり。
- Workspace/Management/ComicWorkspaceAssetsへ画面の生成・確定・破棄を分離。画像管理を離れるとDraftへ保存し、操作を1回のUndoへまとめる。Ctrl+Sは画面を表示したまま未確定の説明も正式保存する。保存失敗では画面と入力を保持する。Undo/Redo、作品やページ切替、解像度変更では管理画面の古いモデル参照を破棄してから進む。ページクリックでは保存に伴う一覧更新前の選択先を保持する。画面を離れると所有する生成要求を中止し、遅延結果の採用を防ぐ。埋込み管理画面でも主フォームが標準ダイアログで無効な間は外部書込・生成結果採用を待たせる。
- 埋込み後のHWND再作成でツリー項目が失われる問題を検証で発見し、子コントロールを構築する前に親・BorderStyle・HWNDを確定した。SelectAssetも同一ノードや通知省略時の入力欄を同期する。
- 開始時のユーザー変更はMangaMaker.dprojとMangaMaker.res。DPI V2・除外パッケージなどの設定を保持し、AppDPIAwarenessModeを共通側にも指定してReleaseへ反映した。IDEの保存で欠落していたMangaMakerSelfTestの条件定義・検索パスだけを復旧した。最初のビルドは通常版として生成され、自己検証要求をexit2で拒否したため、検証成功とは扱っていない。
- Controls/ComicDpi.OwnerControlPPIとCreateScaledNewを使い、所有画面のDPIをフォーム構築前に確定する。ページ基準・生成指示・人物参照・文字入力・素材管理・出力の実行時画面を揃えた。この環境の実DPIは120で、途中のHWND生成によって96基準と120基準が混在する不具合を修正した。埋込み素材パネルもScreen.PixelsPerInchではなくCurrentPPIを使う。編集点の大きさ・当たり判定・文字選択の許容幅を同じDPIで換算し、モニター変更前にドラッグを取り消し、変更後に表示座標を再計算する。行高の拡縮はVCLへ任せ、二重設定によるHWND再作成を避ける。右欄は端数DPIとスクロールバーの余白を考慮して320DIPへ調整した。
- 回帰はTests/Interaction/ComicAssetWorkspaceTestsへ分離。96/144/192/96 PPIの往復、埋込みと非モーダル、一覧項目と選択、文字入力の保存・1回Undo/Redo・再読込、ページ切替、Draftロック失敗・再試行、標準ダイアログ中の外部書込拒否、フォーム3種の非入力IME終了を確認する。既存の画像パン試験は吸着の境界に入っていたためAlt解除を明示し、パン自体と専用スナップ試験を区別した。UIとページ基準の既存試験には失敗時の寸法を診断表示へ追加した。
- 読み取り参照元：Delphi 37.0標準のVcl.Forms.pas（CreateScaledNew、ScaleForPPIRect、SetParent、SetFocusedControl、モニターDPI変更通知）、Vcl.Controls.pas（ScaleForPPI・CMFocusChanged）、Vcl.StdCtrls.pas（リスト行高・ChangeScale）、Vcl.ComCtrls.pas（ツリー選択・HWND作成）。同階層プロジェクトは今回参照・変更していない。
- 開始前の全Source・dproj/res・通常EXE・README/note・既存Git差分はTestOutput/WorkspaceManagement/Beforeへ保持。検証データとログはTestOutput内だけを使用し、実作品・共有設定・サンプル・他プロジェクトには検証用変更を加えていない。ユーザーアプリの強制終了・自動起動、実画像生成、外部送信、commit/pushなし。既知の失敗を修正して再検証する際は、パスと--self-test引数を照合した今回所有の検証プロセスだけを停止した。
- 最終Debugは4763項目PASS（末尾の完了報告行を除く）。fixtureはTestOutput/35e84675836b4287995f49a11c6465fa。build.ps1の180秒待機は超過したが、検証プロセスは完走し、終了後のresult.txtで失敗なしと完了報告を確認した。Releaseも同じソースで4763項目PASS、180秒以内にbuild.ps1が完了した。fixtureはTestOutput/ac653abf28114776932e2b64e6cec655。今回の追加は従来4709項目から54項目。CLIガード3件はexit2、通常Releaseの検証/計測DCUは0件。89ユニットの構成制約、対象PascalのUTF-8 BOM、git diff --checkを確認した。既存ComicPlacementPreviewのH2077以外にエラー・警告なし。
- 検証ログ・CLI結果・ソースハッシュ・更新証跡はTestOutput/WorkspaceManagement/へ集約し、verification.jsonへ記録。asset-workspace-144.pngで左端アイコン・一覧・プレビュー・生成操作の配置を確認した。96/144/192 PPIは隔離VCLによる確認であり、実モニター間の切替や今回の物理IME終了操作とは区別する。
- 実行中の通常アプリがなく、開始前EXEのハッシュと一致することを確認して直下MangaMaker.exeを通常Releaseへ更新した。SHA-256：CDDB51ECB02F36FA2B0528453AD01D94FCEB5C7C98C34B74C15EA5003B65C7C6。旧EXEはBeforeへ保持。MangaMaker.resは開始前のユーザー変更済みファイルとバイト一致へ復元し、dprojのユーザー設定も保持。自動起動・commit/pushなし。

## 新規ページの初期寸法650×975とサイズプリセット（2026-10-18）

- ユーザー指定のニコニコ漫画投稿サイズ650×975pxを新規作品の初期値へ変更。ComicModelのDefaultPageWidth/DefaultPageHeightをモデルと共通ページ基準プリセットで共有する。余白は従来の各60pxを維持し、保存済み作品の寸法と、旧JSONで寸法省略時の1200×1700フォールバックは変更しない。
- 組込みプリセットは先頭650×975、従来1200×1700、1300×1950の3件。既存builtin-standardのIDを維持し、自作プリセットの登録・名前変更・削除・読込も維持する。ページ基準画面では現在の寸法と余白に一致する項目を初期表示し、画面を開くだけでは作品へ適用しない。「設定・管理 → ページ基準・共通プリセット」から選択できる。
- 既存の座標・描画回帰が初期値へ暗黙に依存しないよう、Tests/SupportのCreateFixtureProjectで1200×1700を明示した。既存試験の83か所の作成をこの関数へ置換し、個別指定された寸法は引き続き各試験で適用する。ページ基準試験は組込み件数定数を使い、自作プリセットのインデックスと件数を調整した。
- 追加のComicPageDefaultsTestsは実モデルから新規保存・再読込・650×975 PNG出力・既存1200×1700の保持・旧寸法省略JSON・3種類の選択確定・任意800×1200の登録再読込・取消・96/144 PPI表示を確認する。自己検証時だけ組み込み、通常版には試験用生成関数も含めない。
- 開始前の全Source・通常EXE/res・README/note・Git差分はTestOutput/PageDefaults/Beforeへ保持。既存の未コミット変更を維持し、検証データはTestOutputへ隔離する。実作品・共通設定・同階層プロジェクトは変更せず、今回の読み取り参照はリポジトリ内のみ。
- 最終Win64 Debug/Releaseは各4709件PASS（今回16件追加）、両build.ps1とも180秒以内に完了。CLIガード3件はすべてexit2、通常Releaseの検証/計測用DCUは0件。通常版・最終Release検証のヒントは既存ComicPlacementPreviewのH2077のみ。Debug完了後に試験内の未使用戻り値代入だけを除去し、Releaseで全件を再確認した（製品コードの変更なし）。85ユニットの構成制約、対象PascalのUTF-8 BOM、git diff --checkを確認した。
- DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/233219b65a2e4b8f999982e94f3ccbe0。ReleaseはTestOutput/PageDefaults/ReleaseVerified/MangaMaker.exe、fixtureはTestOutput/73ed4a4d2a9040e782a471fc62e31d9f。debug.log/release.log/production.log、CLI結果、ソースハッシュと更新証跡はTestOutput/PageDefaults/verification.jsonへ記録。posting-page-preset-96.png/144.pngに選択画面を保存し、650×975の初期表示を目視確認した。実際の投稿サイトへのアップロードは行っていない。
- 実行中のMangaMakerがないことと開始前EXEの一致を確認し、直下MangaMaker.exeを通常Releaseへ更新。SHA-256：5B8E67CE20521B500EC7AD275E9252885D85F161D1D6D6AACA2F482DC30CC887。開始前7351A3498ABFC9482543369A07F41329FAA8543B8EFB5227C05E329FBBF62BD4はBeforeへ保持し、resは開始前とバイト一致へ復元した。アプリの強制終了・自動起動、commit/pushなし。

## ページ管理の差分更新と縮小画像の再利用（2026-10-18）

- 編集確定のたびにRefreshUIがFPages/FImagesをClear→全項目追加していた処理を変更。Controls/ComicProjectLists.pasへ一覧の同期を分離し、ページIDの順序が同じなら項目・選択・スクロールを維持し、変化した行だけ背景消去なしで無効化する。通常編集ではBeginUpdate/EndUpdateも呼ばず、WM_SETREDRAWによる全行の再描画を避ける。ページ追加・削除・並べ替え・作品切替時だけ一覧を再構築し、同一作品の選択はIDで引き継ぐ。
- 画像一覧も変更がなければ再構築しない。Undo/Redoでは同一IDのモデルオブジェクトが作り直されるため、古いポインターを参照せず、表示を保ってItems.Objectsだけを現行モデルへ差し替える。ファイル未取得の素材は従来どおり一覧から除外する。
- Rendering/ComicPageThumbnails.pasへ縮小描画キャッシュを追加。ページID・描画内容・解像度・参照ファイルのパス/更新時刻/サイズで照合し、Revision/OutputRevisionだけの変更では失効しない。UndoによるRevisionの巻戻りや同じRevisionの別分岐、未確定変形の描画後の取消も内容比較で追従する。共通画像の更新は参照ページだけを失効し、同じパスの画像更新時は元画像キャッシュも破棄する。ファイル内容の全読み・ハッシュ計算は行わない。
- 縮小画像は表示時にだけ生成し、最大64枚・32MiBでLRU管理する。画面外の変更は見える行を無効化せず、必要時に生成する。削除ページ・作品切替では不要なキャッシュを解放し、DPIによる縮小画像寸法の変更にも追従。Shellは既存のモデル寿命・イベント入口・状態管理を担当し、通常版へ試験用描画カウンターを組み込まない。
- Tests/Interaction/ComicPageRefreshTests.pasで96/144 PPIの実一覧メッセージ（LB_RESETCONTENT/WM_SETREDRAW）、Windowsへ渡した無効化矩形、縮小描画回数、描画ピクセルと履歴を検証する。通常編集・セリフ即時編集・画面外・Undo/Redo/分岐・共有画像更新・並べ替え/追加/削除・未使用画像追加・出力メタ情報・解像度・LRU/メモリー制限を対象とする。非表示窓ではGetUpdateRectが無効化要求を保持しないため、実際のInvalidateRect引数を自己検証時だけControl内へ記録し、要求範囲と描画回数を組み合わせて確認する。Shellへ試験コードを戻さず、通常版からは記録を除外する。
- 開始前の全Source・通常EXE/res・README/note・既存Git差分をTestOutput/PageRefresh/Beforeへ保持。既存の未コミット変更を維持し、検証データはTestOutput内へ隔離する。同階層プロジェクトは今回参照・変更していない。追加の読み取り参照はローカルDelphi標準ソースのVcl.StdCtrls.pas、Vcl.Controls.pas、System.Hash.pas（API宣言の確認）。
- 最終Win64 Debug/Releaseは各4693件PASS（今回139件追加）、両build.ps1とも180秒以内に完了。12ページfixtureで通常編集時のLB_RESETCONTENT/WM_SETREDRAWは0回、サムネイル生成は変更した1枚だけ。共有画像更新は参照する2枚だけで、選択とスクロールも保持した。CLIガード3件はすべてexit2、通常Releaseの検証/計測用DCUは0件。既存ComicPlacementPreviewのH2077ヒント1件以外にビルドエラーなし。84ユニットの構成制約、対象PascalのUTF-8 BOM、git diff --checkを確認した。
- DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/e718b9ceac594bcf9b44083880b92b13。ReleaseはTestOutput/PageRefresh/ReleaseVerified/MangaMaker.exe、fixtureはTestOutput/187e8623751c447484cb8ddd0d015a35。ログ・ソースハッシュ・CLI結果・通常EXE更新証跡はTestOutput/PageRefreshのdebug.log、release.log、production.log、verification.jsonへ保存。page-refresh-96.png/144.pngで対象ページの縮小表示と複数選択/スクロールの維持を目視確認した。非表示VCLでの検証であり、実モニター上のちらつきの手操作計測とは区別する。
- ユーザーの保存・終了の回答後、実行プロセスがないことと開始前EXEの一致を確認し、直下MangaMaker.exeを通常Releaseへ更新。SHA-256：7351A3498ABFC9482543369A07F41329FAA8543B8EFB5227C05E329FBBF62BD4。開始前EXE（A078D6C945A754502535E7A96FCD6BA461AFF0571E1D79592BD895BB494128B1）はBeforeへ保持し、resは開始前とバイト一致へ復元した。アプリの強制終了・自動起動、commit/pushなし。

## 文字サイズの記憶と吹き出し編集のコマ選択禁止（2026-10-18）

- 文字サイズ欄を選択専用から数値入力可能へ変更。1～1000の整数を一覧から選択・直接入力すると即時反映し、Presets/FontSize.jsonへ最後の指定値を保存する。吹き出し未選択でも次回の既定値を指定でき、再起動時の欄と新規配置へ引き継ぐ。未設定時は24。既存セリフの選択・読込・Undo・ドラッグ拡縮では明示指定の既定値を書き換えない。
- 空の既存吹き出しへの直接入力は、最後のサイズを取消可能なプレビューへ適用し、文字確定時にサイズも保存する。既存セリフは自身の保存サイズを維持。空・非数・範囲外の入力では作品・履歴・既定値を変更しない。設定ファイルの破損・保存不能では既存ファイルを保持し、今回の起動中の指定は利用できる。
- 吹き出し画面へ入るとコマ選択を解除し、コマの当たり判定から移動・拡縮へ進む経路と選択枠表示を止めた。古いコマ選択が残っていても押下時に除去する。コマ削除・画像D&Dからのコマ選択も同画面では行わない。吹き出し本体・セリフ・しっぽの操作と、新規吹き出しの所属コマ判定は維持する。
- 回帰はSource/Tests/Interaction/ComicBalloonSelectionTests.pasへ分離。一覧・直接入力・再起動・旧セリフ・空文字プレビューの取消/確定・保存再読込・不正値/設定破損/保存失敗と、96/144 PPI・0.75/1.5倍でコマ本体/8点の誤操作防止・本体操作・入力からの枠選択・T・所属判定を検証する。既存入力試験が保存する文字サイズ設定も試験終了時に復元し、試験順への依存を避ける。
- 開始前の全Source・通常EXE/res・README/note・Git差分はTestOutput/FontSizeSelection/Beforeへ退避。既存の未コミット変更を保持し、実作品・通常設定・同階層プロジェクトへ検証データを入れていない。今回の追加参照はリポジトリ内のみ。
- Win64 Debug/Releaseは各4554件PASS（今回125件追加）。両build.ps1は180秒の待機上限を超えて終了したが、検証プロセスは継続し、終了後のresult.txtで全件PASSと末尾の完了報告を確認した。待機成功とは区別してverification.jsonに記録する。CLIガード3件はすべてexit2、通常Releaseの検証/計測用DCUは0件。ビルドエラーなし、既存ComicPlacementPreviewのH2077ヒント1件のみ。81ユニットの構成制約、対象PascalのUTF-8 BOMとgit diff --checkを確認した。
- DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/773508b8e7034808b243273c50c4b33a。ReleaseはTestOutput/FontSizeSelection/ReleaseVerified/MangaMaker.exe、fixtureはTestOutput/d263d540813549aaad53d0646296699e。ログ・ソースハッシュ・CLI結果・更新証跡はTestOutput/FontSizeSelectionのdebug.log、release.log、production.log、verification.jsonへ保存。balloon-no-panel-selection.pngで古いコマ選択が残っていても編集点・選択枠が表示されないことを目視確認した。非表示VCLへのイベント通知での検証であり、物理マウス・IME候補の手操作は含まない。
- 実行中のMangaMakerがないことと開始前EXEの一致を確認し、直下MangaMaker.exeを通常Releaseへ更新。SHA-256：DB2460B6F396D9E61AE34D2166D792EA45E1EC65464E1174D1BF41E3008D7553。開始前直下EXE（66484CD78BDA4699B42AE8C7330A9C06EE52281244D430938C499BCD5041C3B8）はBeforeへ保持し、resは開始前とバイト一致へ復元した。アプリの強制終了・自動起動、commit/pushは行わない。

## コマ・画像の誤移動防止と素材D&Dの原寸/比率維持（2026-10-18）

- 最新依頼に対応し、コマ本体と配置画像の移動だけに「250ms未満かつ6DIP未満」の保護を追加した。DPIに応じた画面距離を使用し、表示倍率に依存させない。時間または距離のどちらかを満たすと開始する。一度意図した移動として認識したジェスチャは、開始点へ近づいても継続する。未認識中はスナップも適用せず、短い手ぶれで配置・Draft・Dirty・Undo/Redoを変更しない。
- 判定値はControls/ComicDragIntent.pasへ集約。Shellは押下Tickを保持し、WorkspaceInteractionが単体/複数コマ・画像の移動へだけ適用する。拡縮点・頂点・文字・しっぽ・素材の移動/回転と表示パンは従来の反応を維持する。小さく動かした後に長押ししたケースや最後のMouseMoveが省略されたケースもMouseUpで判定する。すでに処理した同じ終点は再計算せず、Altによるスナップ解除などの途中状態をMouseUpで上書きしない。
- 漫画効果素材の新規D&DはPNGの実ピクセル寸法とコマ寸法を比較し、倍率min(1,コマ幅/PNG幅,コマ高さ/PNG高さ)で中央へ配置する。小さい素材は拡大せず、大きい素材だけアスペクト比を維持して収める。正規化したOverlay.Boundsへ保存し、既存の移動/比率維持拡縮/回転/Undo/再読込と共有する。既存配置の自動再配置や原本PNGのリサンプルは行わない。
- 素材サイズ計算はComicEffects.FitEffectBoundsへ分離し、PNG寸法の検証後・作品への追加前に決定する。作品へのPNGコピーは従来どおり。旧素材回帰はコマ全体への引き伸ばしから原寸64×64の期待へ変更し、半透明画素の検証座標と拡縮時の元アスペクト比を更新した。
- Tests/Interaction/ComicDragDropTestsは時計を待たず押下Tickを設定し、96/144 PPIと倍率0.75/1.5で短い手ぶれ、意図した微調整、素早い大移動、開始点付近への戻り、長押し後の離し、末端通知の省略、複数選択、既存Redoの保持、拡縮の即時性を検証する。素材は小型、横だけ過大、縦だけ過大、縦横過大、コマと同寸を実D&Dから検証し、原本ハッシュ・保存再読込・Undo/Redoも確認する。途中で発見した旧Alt解除試験への影響は同じMouseUp終点の再処理を避けることで修正した。
- 作業前の通常EXE/res、全Source、README/note、既存Git差分はTestOutput/DragAndDrop/Beforeへ保持。実作品・共有設定・同階層プロジェクトを検証用に変更していない。

- Win64 Debug/Releaseは各4429件PASS（今回358件追加）、両build.ps1は180秒以内に完了。CLIガード3件はすべてexit2、通常Releaseの検証/計測用DCUは0件。ビルドエラーなし、既存ComicPlacementPreviewのH2077ヒント1件のみ。80ユニットの構成制約、対象PascalのUTF-8 BOM、git diff --checkを確認した。既存の小移動スナップ試験は長押し済みの意図した操作として時刻を設定し、誤操作判定の試験と区別した。
- DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/e22a83c80d9c437187ddb0b696bc237f。ReleaseはTestOutput/DragAndDrop/ReleaseVerified/MangaMaker.exe、fixtureはTestOutput/70d17ee6ed6d43349a5d63e21bfb85f8。material-fit-wide.pngで横長素材が縦長コマへ引き伸ばされず、中央に比率維持で収まることを目視確認した。全ログ・CLI結果・ソースハッシュ・更新証跡はTestOutput/DragAndDrop/verification.jsonとdebug.log/release.log/production.logに保存。操作は非表示VCLフォームへのイベント通知で検証し、実マウスの手ぶれ試験とは区別する。
- 実行中のMangaMakerがないことと開始前EXEの一致を確認して直下MangaMaker.exeを通常Releaseへ更新。SHA-256：85643CE5AE00F24F8A453058C7B53BBA20A7325C6C15C76B05C5EC96E1768F21。開始前版07010D9F8183C133D00D2054A60A6B1208A5885AD2DB2C528536AF2C1EE68A1BはBeforeに保持し、resは開始前とバイト一致へ復元した。アプリの強制終了・自動起動、commit/pushなし。

## ページ解像度変更時の中心基準・縦横同率拡縮（2026-10-18）

- 最新依頼により「ページ基準の解像度を変えても既存座標を維持する」動作を変更。倍率はmin(新幅/旧幅,新高さ/旧高さ)、座標は新ページ中心＋(旧座標−旧ページ中心)×倍率。全ページのコマ・画像・吹き出し・しっぽ・効果をまとめて変換する。幅/高さ比が異なると全体を新ページ内へ収めて中央へ配置する。入力した外枠余白はそのまま適用し、余白だけの変更では配置を動かさない。
- 独立計算・候補の検証はSource/Editing/ComicPageResize.pasへ分離。複製した作品上で全ページを変換し、保存JSONを再読込できることまで確認してからShellへ渡す。元作品を変更せずに不正な最小寸法・しっぽ・座標・線幅を検出する。Shell.ApplyPageBasisは成功後に1回のUndoを追加し、保存失敗では元の作品・Dirty・履歴を保持し、部分Draftの復元も試みる。適用前には未確定ドラッグを取消し、入力中の文字を従来どおり確定する。
- コマは四角/楕円/角丸/多角形の全頂点と線幅を同率変換する。画像のCover倍率はコマ寸法へ追従するため、Zoomは保持しPanX/Yだけを同率変換して切り抜きを維持する。効果は正規化されたコマ内座標と回転角を保持することで、中心・縦横サイズが同率で追従する。原本画像・素材PNGは再サンプルしない。
- 吹き出しは既存ApplyTransformの文字込み変形を使い、本体・相対文字位置・三角/思考しっぽの根元/先端/幅を一括変換。文字サイズは倍率に最も近い整数（既存の1～1000内）にする。既存の文字組版基準を保持し、未設定の組版基準は変更前の寸法・文字サイズで確保するため、自動/手動の改行と文字間隔/行間隔の比率を維持する。
- 二重枠の固定8px間隔も同率で変えるためTComicPanel.FrameGapを保存（旧JSON省略時は8）。通常のコマ拡縮では従来どおり維持し、ページ解像度変更時だけ線幅と共に拡縮する。各ページのRevisionを1増やしOutputRevisionを無効化、renderer-16で出力の署名を更新。余白だけの変更では各ページのJSONと完成PNGキャッシュを保つ。
- Source/Tests/Interaction/ComicPageResizeTests.pasで全2ページ・4形状・回転素材・三角/思考しっぽ・縦横文字・自動/手動改行、拡大/縮小/幅のみ/高さのみ/縦横比変更/端数サイズを検証。原本のハッシュ維持、画像の切抜き、2倍解像度での同じ表示寸法の画素一致、保存再読込、全ページUndo/Redo、同値の再適用、余白だけの変更、最小しっぽと保存ロックによる全体保持も確認する。従来PageBasis試験の期待を新しい半分の座標へ更新した。
- 作業前のEXE/res、全Source、README/noteと既存Git差分はTestOutput/PageResize/Beforeへ保持。実作品・共有設定・同階層プロジェクトを検証用に変更しない。

- Win64 Debug/Releaseは各4071件PASS（今回522件追加）、両build.ps1は180秒以内に完了。CLIガード3件はすべてexit2、通常Releaseに検証/計測用DCUは0件。ビルドエラーなし、既存ComicPlacementPreviewのH2077ヒント1件のみ。78ユニットの構成制約、対象PascalのUTF-8 BOM、git diff --checkも確認した。
- DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/2797ad354b244a29a95fc5f98902c425。ReleaseはTestOutput/PageResize/ReleaseVerified/MangaMaker.exe、fixtureはTestOutput/d3cbc938d49042f4a94fc0fda2e0b4f1。2倍解像度で同じ表示寸法の完成画素が一致すること、端数倍率でも行/列数と画像の切抜きを維持すること、余白だけの変更ではページJSONが同一なことを確認した。全ログ・CLI結果・ソースハッシュ・更新証跡はTestOutput/PageResize/verification.jsonとdebug.log/release.log/production.logに保存。
- 実行中のMangaMakerがないことと開始前EXEの一致を確認して、直下MangaMaker.exeを通常Releaseへ更新した。SHA-256：07010D9F8183C133D00D2054A60A6B1208A5885AD2DB2C528536AF2C1EE68A1B。開始前版645C29EF98BBA8A2225119EE56B5F40DC3E9213D894E670FFF87ED3E0D3E2B3DはBeforeに保持し、resは開始前とバイト一致へ復元。アプリの強制終了・自動起動、commit/pushなし。

## 漫画効果の回転ハンドル（2026-10-18）

- 最新依頼に対応し、効果素材の選択枠へ上辺中央から36DIP伸びる線、丸、曲線矢印の回転ハンドルを追加。ハンドルの描画・当たり判定は表示倍率によらずDPIに応じた画面サイズを維持する。枠と8点も回転へ追従し、回転ハンドルは手形、移動は移動、拡縮は向きに応じたカーソルになる。回転角はステータスへ表示し、Shiftで15度刻み。
- TComicOverlay.Rotationを度数で保存する。旧JSONのrotation省略時は0度で、非有限値・360度を超える絶対値は読込時に拒否。マウス回転は中心から押下位置/現在位置への偏角差を開始角へ加え、-180〜180度へ正規化する。素材の中心・幅・高さ・原本PNGは回転で変更しない。
- 計算はEditing/ComicOverlayTransform、選択枠はRendering/ComicEffectSelection、透明画像とGDI+用メモリストリームの寿命はRendering/ComicOverlayDrawingへ分離。WorkspaceEffectsへ効果のイベント処理を集め、Interactionは入口、Shellは開始角などの状態を担当する。傾いた拡縮はドラッグ差分を素材のローカル座標へ戻し、反対側の点をページ座標で固定する。回転ハンドルがコマ外でも空白パンへ渡さない。
- 回転時だけGDI+で透明度を保って描画し、0度は従来のPNG描画経路を維持。メモリ上のPNGストリームを画像と同じ寿命で持ち、ファイルのロックを残さない。描画中のコマ/ページのクリップを引き継ぐ。DC原点はGDI+が引き継ぐため座標を二重に変換しない。途中検証で発見したPaintTo時の二重変換による位置ずれは修正した。完成描画/サムネイル/出力で同じ角度を使い、連番出力の署名をrenderer-15へ更新。
- Tests/Interaction/ComicEffectRotationTestsで中心回転、正負・180度越え、Shift、8編集点の判定と固定点、角度JSON/旧形式、透明合成、楕円クリップ、移動したDC原点、原本の排他オープン、実連番PNG/キャッシュを検証。実フォームイベントは96/144 PPI・倍率0.75/1.5・開始角0/33/170度で、ホバー/ドラッグ/1回Undo/Redo/保存再読込/Esc/無移動クリックを検証する。
- 読み取り参照：C:/Program Files (x86)/Embarcadero/Studio/37.0/source/rtl/win/Winapi.GDIPOBJ.pas（Graphics、DrawImage、SetClip、初期化・寿命）およびMicrosoft LearnのGraphics::SetClip(HRGN,CombineMode)（https://learn.microsoft.com/en-us/windows/win32/api/gdiplusgraphics/nf-gdiplusgraphics-graphics-setclip%28hrgn_combinemode%29）。参照元は変更していない。
- 作業前の通常EXE/res、README/note、全Sourceと既存Git差分をTestOutput/EffectRotation/Beforeへ退避。既存の未コミット変更、実作品、共有素材を保持。検証の画面・作品・出力はTestOutput内だけで作る。

- Win64 Debug/Releaseは各3549件PASS（今回追加の195件を含む）、両build.ps1は180秒以内に完了。CLIガード3件はすべてexit2、通常Releaseの検証/計測用DCUは0件。コンパイルエラーなし、既存ComicPlacementPreviewのH2077ヒント1件のみ。76ユニットの構成制約、対象PascalのUTF-8 BOM、git diff --checkを確認した。
- DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/38f81fb025de4eabb1774dd7b9c75ae5。ReleaseはTestOutput/EffectRotation/ReleaseVerified/MangaMaker.exe、fixtureはTestOutput/766f4bfe8ac843a58f345af9aa5f9dcb。effect-rotation-handles.png、rotation-alpha-clip.png、rotation-clip-reference.png/rotation-clip-shifted.pngで丸と矢印・回転枠・透明合成・クリップ・DC原点を目視確認した。検証ログ、CLI結果、ソースハッシュと更新証跡はTestOutput/EffectRotation/verification.jsonと同フォルダーのdebug.log/release.log/production.logに保存。検証操作は非表示VCLフォームへのイベント通知で、実マウス操作とは区別する。
- 実行中のMangaMakerがないことと開始前EXEの一致を確認し、直下MangaMaker.exeを通常Releaseへ更新。SHA-256：645C29EF98BBA8A2225119EE56B5F40DC3E9213D894E670FFF87ED3E0D3E2B3D。開始前版F92FF5CAC40663CD6DF750AC287C2508FF186DEA377C2A458BFA339EB2DEB36FはBeforeに保持し、resは開始前とバイト一致へ復元した。アプリの強制終了・自動起動、commit/pushなし。

## 吹き出し配置の完成表示・入力時センタリングの訂正（2026-10-18）

- 最新指示を優先し、前回記録した「吹き出し配置の白黒点線」と「入力開始位置の固定」を撤回した。吹き出し本体としっぽは配置中から完成時と同じ塗り・輪郭で描画する。コマの配置予告だけは従来の白黒点線を維持する。
- ComicPlacementPreviewは新規本体、または選択本体を複製してしっぽを足した一時モデルを返す。ComicRender.Drawで新規本体を重ね、既存IDは同じ描画順で差し替える。本体としっぽの結合輪郭、色、太さ、所属コマのクリップを完成描画と共有し、ページ・Undo・保存・PNG出力へ予告モデルを登録しない。
- ComicInlineTextの挿入原点固定と、それに伴うTextOffsetの自動補正を削除した。文字追加・削除・IME未確定・明示改行のたびに、完成表示と共通の中央揃えで組版する。手動で動かした相対位置と文字サイズは維持する。AutoWrap=falseは保持し、枠を超えても勝手に行・列を増やさず、Enterによる改行だけを採用する。旧作品の自動折り返しは読込だけでは変更せず、直接入力を開始して確定したセリフから手動改行へ移る。
- 96/144 PPI、ドラッグ/2点クリック、全4輪郭、三角/思考しっぽで予告と配置確定後の画素比較を追加した。縦横入力・IME未確定・削除・明示改行でセンタリングと相対位置維持、自動折り返しなし、既存倍率、取消/Undo/保存再読込も検証する。画面キャプチャで実際の塗り・結合しっぽ・枠を超える1列の縦書きとキャレットを確認した。
- 作業前のEXE/resと既存差分をTestOutput/CenteredPreview/Beforeへ退避。既存の開発差分と実作品を保持し、同階層プロジェクトの変更、強制終了・自動起動、commit/pushは行わない。検証結果・通常EXEの更新証跡は同フォルダーに記録した。

- Win64 Debug/Releaseは各3354件PASS、build.ps1の180秒以内に終了し、CLIガード3件はすべてexit2。ビルドエラーなし（新規プレビュー作成の例外経路にH2077の未使用代入ヒント1件）。通常Releaseの検証/計測用DCUは0件。72ユニットの構成制約、対象PascalのUTF-8 BOM、git diff --checkも確認した。非表示VCLと模擬IME通知による検証であり、物理IME候補の手操作は含めない。
- DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/9ee90311587d459788ee1e24c1336297。Releaseのビルド・fixture・ソースハッシュ・CLI結果はTestOutput/CenteredPreview/verification.jsonに記録し、debug.log/release.log/production.logも同フォルダーへ保存した。予告本体・結合しっぽ・センタリングのキャプチャは両fixtureのplacement-preview-5.png、placement-preview-7.png、inline-manual-overflow-caret.png。
- 実行中のMangaMakerがないことと、作業前EXEの一致を確認し、直下MangaMaker.exeを通常Releaseへ更新した。SHA-256：F92FF5CAC40663CD6DF750AC287C2508FF186DEA377C2A458BFA339EB2DEB36F。開始前版3EDF31B3729D5CC9A5FBBA84D3FACF89D97727B6E617EC14EB3ED47832C2743CはBeforeに保持し、resも開始前とバイト一致へ戻した。アプリは自動起動していない。

## ドラッグ配置・セリフ中心吸着・入力位置の固定（2026-10-18）

- 本体選択Sでも、見えているセリフの内部をクリックするとセリフ選択T/Vへ移る。初回クリックだけでは入力に入らず、同じ押下からドラッグ移動できる。既存の縦横を維持し、本体の8点を優先する。小さな文字で編集点が重なる場合は最寄りの点を選び、編集点の間の内部を移動・入力へ残す。前面の不透明本体と所属コマのクリップも選択判定に考慮した。
- 新規文字サイズは40から24へ変更し、サイズ一覧へ16・20・28も追加。旧作品の保存値と、fontSize省略時の従来値40は保持する。新規三角しっぽは従来の根元幅を2倍へ変更（上限2000）。思考しっぽと既存のしっぽは維持した。
- セリフ移動時は実際の文字範囲の中心を、吹き出し本体の中心へ軸別に吸着させる。許容幅は8px×DPI/表示倍率、Altで一時解除、既存のスナップ設定と共通。吸着中だけマゼンタの中心点線を編集キャンバスへ重ね、終了・取消で消す。計算はComicDialogueTransform、状態はShell、描画とイベントはWorkspaceへ分担した。
- 四角・楕円・角丸のコマと吹き出し、三角・思考しっぽの2点配置を既定でドラッグへ変更。「設定・管理 → 2点配置をドラッグで操作」のチェックを外せば2点クリックへ即時切替でき、保留中の予告は取消す。ドラッグ終端でだけ配置し、プレビューでは作品・Undoを変更しない。6px×DPI未満の距離、または本体の幅/高さが30ページpx未満なら配置しない。マウス捕捉喪失・Esc・画面切替でも取消し、ドラッグ中のホイールは座標系を変更しない。多角形・分割の多点操作は保持する。
- 配置予告をSource/Rendering/ComicPlacementPreview.pasへ分離。最終描画と共通の本体・しっぽ領域を使い、輪郭を透明な内側と白黒の点線で表示する。編集中ページの範囲へクリップし、PNG出力に含めない。
- 最新の回答「自動折り返しせず、Enterで改行したときだけ次の行・列へ進む」を採用した。新規モデルはautoWrap=false、旧JSONで省略時はtrue。直接入力開始時の最初の挿入位置を固定し、文字追加・IME未確定文字で原点や文字サイズを動かさない。枠を超えた文字はそのまま続け、明示改行だけで次の行・列へ移る。空文字のレイアウト原点を中央へ置き、入力前からキャレットを表示する。確定時は入力中の相対位置と組版の基準倍率を保存し、完成表示へ戻ったときの移動も防ぐ。旧自動折返しのセリフは読込時に維持し、直接入力を取消すと元へ戻り、確定したものから手動改行へ移る。専用入力も手動改行に対応し、レンダラー署名を14へ更新した。
- 回帰はSource/Tests/Interaction/ComicPlacementTests.pasへ分離し、自己検証時だけ検索パスへ追加。既存の2点クリック検証は切替後の方式を明示し、描画ピクセルの期待がフォントに依存する輪郭試験は文字サイズ40のfixtureを明示した。開始前の通常EXE/resと差分はTestOutput/DialoguePolish/Beforeへ保持。既存の未コミット変更を維持し、実作品・通常設定・同階層プロジェクトを検証用に変更しない。
- 最終Win64 Debug/Releaseは各3289件PASS、CLIガード3件はすべてexit2。通常Releaseもエラー・警告・ヒントなし、検証/計測用DCUは0件。新規相互操作試験では96/144 PPI、ドラッグ/2点クリック、8種類の配置、狭い配置の破棄、捕捉喪失と方式切替、白黒の予告、中心吸着/Alt解除/一時ガイド、直接クリック選択、空文字キャレット、枠を超える手動改行、旧折返しの取消、基準倍率維持、保存再読込を確認した。保存可能な相対座標を超えた場合も保存前に拒否し、作品と入力バッファを保つ。
- 最終試験を並行実行した際は両構成ともbuild.ps1の180秒待ち時間を超えた。試験プロセス自体は継続し、終了後のresult.txtで各3289件とFAILなしを確認した。スクリプトの待機成功とは区別してverification.jsonにも記録する。途中版で見つかった空白クリックによるセリフ選択解除漏れは修正済み。物理IME候補操作・実モニター切替は未検証で、非表示VCLと模擬IME通知による検証と区別する。
- DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/aa07f1f8261843e2a57ceb40004147d6。ReleaseはTestOutput/DialoguePolish/ReleaseVerified/MangaMaker.exe、fixtureはTestOutput/f476b4f1a6b244b08fe27a69cafb6155。ビルドログは同フォルダーのdebug-verified.log、release-checked.log、production-verified.log。placement-preview-5.png、placement-preview-7.png、dialogue-center-guides.png、inline-manual-overflow-caret.pngで配置予告・一時ガイド・枠外文字とキャレットを目視確認。証跡とソースハッシュはTestOutput/DialoguePolish/verification.json。
- ユーザーの「保存して終了しました」を受領し、実行中の通常アプリがないことと開始前EXEの一致を確認して、直下MangaMaker.exeを通常Releaseへ更新した。SHA-256：3EDF31B3729D5CC9A5FBBA84D3FACF89D97727B6E617EC14EB3ED47832C2743C。開始前版2368B25E533FEE3798388C8136AA43EA6DE32CDD041A0B42DDF674127D6AF539はBeforeへ保持。resは開始前退避とバイト一致へ復元。72ユニットの構成制約・日本語PascalのUTF-8 BOM・git diff --checkを確認。アプリの強制終了・自動起動、commit/pushなし。

## 吹き出し・セリフ選択と設定の即時反映（2026-10-18）

- 本体選択Sとセリフ選択T/Vを分けた。入力中に文字の外側の本体・枠をクリックすると入力を確定し、本体選択へ渡す。その状態からTでセリフの8点を選択し、クリックまたはEnterで直接入力を開始する。Tの縦書き基本・再押下で縦横切替は保持。入力中の文字キーは入力側へ渡す。
- セリフの移動は本体中央からの相対座標。四隅は文字サイズの比率維持拡縮。上下・左右の中央点は、縦書きなら文字間隔・行間隔、横書きなら行間隔・文字間隔を変更する。計算はSource/Editing/ComicDialogueTransform.pasへ分離。文字間隔・行間隔を0.25〜8の比率で保存し、旧作品では各1として読む。共通組版で折返し・字形寸法を保って始点とキャレットを調整し、入力・表示・PNG出力で共有する。縦中横の内部キャレットは字形内に保持する。
- 本体8点と移動領域のホバーでカーソルを変更。通常の本体拡縮では文字サイズを保持し、Ctrl併用時だけ従来の文字込み拡縮を行う。しっぽと相対文字位置はどちらも追従。IME未確定中にアプリ独自で描いていた下線を除去し、明示的なフォント下線は保持した。
- 「文字・設定を反映」ボタンを撤去し、文字・フォント・装飾・縦横・色・輪郭等を変更すると即時保存・再描画する。選択時のコントロール読込と入力プレビュー同期は変更イベントを抑制。メモ欄の連続入力は同じフォーカスの間を1回のUndoへまとめる。保存に失敗した設定は作品・Revision・Undo・コントロールを復元する。台本セリフの選択も即時反映へ変更し、専用入力画面内の取消可能なプレビューは維持した。
- 最後に選んだフォントをFontHistory.jsonの先頭から復元し、新規吹き出しと空の吹き出しへの入力に使用する。空の既存吹き出しは入力プレビューだけへ優先フォントを設定し、確定時に文字と一緒に保存する。既存セリフの編集では元のフォントを保持。履歴は既存の上限10件・重複除去・保存失敗復元を使い、次のドロップダウンで先頭へ並べる。フォント選択直後に開いている項目の順序を変えない。
- 読み取り参照元は直下の前回記録と同じ。今回の追加変更で同階層プロジェクトを変更していない。開始前の差分と通常EXE/resはTestOutput/BalloonRefinement/Beforeへ保持し、既存の未コミット変更を維持する。実作品・通常設定を自己検証に使用しない。
- 最終Win64 Debug/Releaseは各3085件の自己検証PASS（末尾の完了報告行は件数から除外）、CLIガード3件はすべてexit2。通常Releaseもエラー・警告・ヒントなし、検証/計測用DCUは0件。8方向ホバー、通常/Ctrl本体拡縮、四隅の折返し維持、小数座標、辺の間隔・字形寸法・対辺固定、縦中横キャレット、入力→本体→セリフ選択、即時設定、メモ入力の履歴集約、保存ロック失敗の復元、旧形式読込、フォントの再起動復元・新規作成・空の既存吹き出し入力・既存フォント維持を確認。96/144 PPIは隔離VCL描画で検証し、物理IME候補操作・実モニター切替は未検証。
- 指定DebugはTestOutput/Verified/MangaMaker.exe、fixtureはTestOutput/d79ec1ddadc048d6a9d1883e14bd71d1。ReleaseはTestOutput/BalloonRefinement/ReleaseVerified/MangaMaker.exe、fixtureはTestOutput/e2f344ee9a1a4ec8b45c154e7e28ee09。ログはTestOutput/BalloonRefinement/debug-final-verified.log、release-verified.log、production.log。dialogue-selection-144.png、dialogue-settings-live.pngと既存の入力描画画像を確認した。証跡とソースハッシュは同フォルダーのverification.json。
- 通常アプリが終了していることと開始前バックアップの一致を確認し、直下MangaMaker.exeを検証済み通常Releaseへ更新した。SHA-256：96F3BC8F490FB7A16D444F63D98FED234B94103FCE23D71CE7E1E86C6E9121BC。開始前版9D5EBF4AD1DDBB953330A781B5203AF0D0118BF59EE9AC9BCC70FC59166680A4はBeforeへ保持。アプリの強制終了・自動起動は行っていない。ビルドが生成したresはBeforeのバイト列へ戻し、70ユニットの構成制約・日本語PascalのUTF-8 BOM・git diff --checkを確認した。commit/pushなし。

## 吹き出しのキー切替とページ上の文字編集（2026-10-18）

- 最新依頼に従い、吹き出し画面へS（選択）、T（文字）を追加。Tは別ツールから選ぶと縦書き、入力開始前に再度押すと横書きへ切替。U/Shift+Uは四角・楕円・角丸の順/逆切替、Pは三角/思考しっぽ、Aはしっぽ編集、Vは文字配置、Delは吹き出し/編集中のしっぽ削除。U/TはCLIP STUDIO PAINT公式のTool Shortcutsを参照し、その他は既存機能へ割当。キーと操作はアイコンのヒント・説明・READMEへ記載した。
- 新しい吹き出しは空文字・縦書きで作成する。Tで文字ツールを選んで吹き出しをクリックすると、ページ上で直接入力・編集できる。選択ツールでのダブルクリックも直接編集へ変更し、既存の縦横を保持する。右側TMemo、台本セリフ補完、従来の専用入力画面は保持。文字編集中のS/T等は文字へ渡し、ツール切替や作品Undoで奪わない。
- Source/Text/ComicInlineText.pasは既存TComicTextInputのUTF-16編集バッファ・IME受取・入力内Undoを再利用する。作品から複製したプレビューだけを編集し、RendererのBuildBalloonTextLayoutで完成ページと同じフォント・折返し・中央配置・倍率を使う。ネイティブ受取窓は描画せず画面キャレットへ追従させ、選択範囲とIME未確定文字をキャンバスへ重ねる。縦書きキャレットは横線、横書きは縦線。ページ/所属コマのクリップを維持し、PNG出力へ編集表示を入れない。
- Enterは改行、Ctrl+Enterは確定、Escは取消。ドラッグ・Shift+矢印の選択、コピー/切取り/貼付け・削除・入力内Undo/Redo・単語移動を使用できる。中央配置の負座標でもHome/Endと行/列間の希望位置を正しく扱うため、共有組版へ行端取得、入力側へ希望位置の有効フラグを追加した。
- 別操作・フォーカス離脱・ページ/画面/作品切替の前に入力を確定し、管理画面や保存/Undoと競合させない。IME未確定のEnter/EscはIMEへ渡し、操作移行では変換完了を要求してから終了する。Draft書込成功後に1回の作品Undoへ追加し、書込失敗では元データと履歴を復元して入力バッファを保持する。編集中の外部書込要求を拒否し、状態照会は許可する。
- 読み取り参照元：指定された D:/DelphiProg/SYNC_ScreenLayout/SYNC_ScreenLayout_Filter.dpr、同プロジェクトnote.md、Source/Editor/Interaction/Text/ScreenLayoutTextEditing.pas、Source/Editor/ScreenLayoutCanvas.pas（TextEditorKeyDown、UpdateTextEditorBounds）、Source/Rendering/ScreenLayoutTextEditOverlay.pas。参照先にAGENTS.mdはなく、Git状態は開始/終了とも変更なし。他プロジェクトを検索パスへ追加していない。
- 以前ビルド制限で未検証だった既存差分も今回の全体回帰へ含めた。そこで検出したComicImageLayoutTestsのSystem.Classes不足、非表示画像管理へのSetFocus（Showing時だけ行う）、右端吸着テストと上下端の近い候補の競合（試験配置で切り分け）、画像一覧ヘッダー98pxに対する古い56pxの期待値を修正した。ダブルクリックの旧TMemoフォーカス検証は新しい直接編集の検証へ更新。既存の開発差分を取り消していない。
- 最終Win64 Debug/Releaseは各2531項目PASS、通常Releaseもエラー/警告/ヒントなし。入力・IMEイベント・文字選択・縦横キャレット・96/144 PPIと表示倍率1/2・保存再読込・取消・Undo/Redo・保存ロック失敗/再試行・外部書込拒否・画面切替を検証。物理的なIME候補選択/実変換・実モニターDPI切替は未検証で、模擬IME通知と隔離VCL描画を実機操作の代替とは扱わない。
- 指定Debugの出力はTestOutput/Verified、ReleaseはTestOutput/Verified-Release。最終fixtureはDebug TestOutput/789c6a75f06b45e5bf84a45132bf4cd2、Release TestOutput/4ea5c5df9f8f47c6bd72b0f42077f44f。TestOutput/InlineText/へビルドログ、CLI結果、source-hashes.csv、verification.json、旧EXE/res/開始時差分を保持。Debug/ReleaseのCLIガード各2件と通常版の自己検証拒否はすべてexit2。通常版のテスト/計測DCUは各0件。構成検査69ユニット、git diff --check、日本語PascalのUTF-8 BOMを確認した。
- 起動中のMangaMakerがないことと開始時EXEの保持を確認して、通常起動用MangaMaker.exeを通常Releaseへ更新した。SHA256は193F0FB87DE57D7EE1C45A4DFFAEDF65AD857DF1073C52F86412884C643FDD55。MangaMaker.resは開始時退避からバイト一致で復元。ユーザー作品・共有ライブラリや他プロジェクトを更新せず、ユーザーアプリの起動/強制終了・画像生成・外部送信・音・commit/pushは行っていない。

## 追加の和室背景と目覚めの2コマを制作（2026-10-17）

- ユーザー依頼「2コマ増やした、背景とともに作成して送信して」に従い、起動中のbridge-27380.jsonから同じ作品の新規3項目を取得。台本ID外の手動追加項目で、B011（ED5DF879-E90E-47AC-950B-1AE8D1472A48）、目が覚める（B92C2380-ED4B-4566-903A-4892B2E6E541）、ほっとする（C4536DB2-AD1F-4F20-BE3B-7C3564C49509）を対象とした。名前やUIDを変えず、追加登録もしなかった。
- 内蔵image_genで1枚ずつ生成・目視確認し、背景→目が覚める→ほっとするの順で既存register_imageへ送信。人物は登録済みの東北きりたん／裸足（5D8E9588-5A60-4C46-A372-B6CF47EDF862）の三面図を毎回優先。下半身は布団内、上半身の衣装・顔・大きい頭と短い胴腕を維持した。
- B011は朝の和室、左手前の生成り敷布団/淡い青緑の掛け布団、右奥の低い木机、机上の濃灰大型タブレット一台とスマホ/グリップ/ファーマイク一組、机下の黒バッグを固定。「目が覚める」は布団に入ったまま上半身を起こす驚き、「ほっとする」は同じ位置で機材を見る安堵の横顔。文字・吹き出し・擬音なし。
- 開始時「ほっとする」の編集欄draftNotesにある「機材の方を見てほっとする」も読取り、後続のgeneration_contextで同じnotesを再取得して生成指示に反映。親背景登録後に子のcontextを取り直し、未取得fileとexpectedContextを照合して送信した。アプリ側連続生成・GUI操作なし。
- 新3点すべて管理PNGと生成PNGのSHA256一致。既存59点のfile参照を保持し、全62点が取得済み。証跡・内蔵image_genの指示・PNGはTestOutput/AddedPanels/、verification.jsonと生成記録.txtにまとめた。通常キャラライブラリ・製品コード/EXEは今回無変更。既存の開発差分とビルド制限には触れず、ビルドは実施していない。

## 画像管理メニューの名称・順序・Del（2026-10-17・実行検証待ち）

- 最新指示により先頭を「新規場面」「場面移動」「コマを作成」の順へ変更。「場面移動」は既存alternate_scene（同じ場面の別位置背景を追加）、「コマを作成」は既存child（コマ用の派生画像登録）の名称変更。新しい移動やページのコマ枠作成機能は追加しない。子の初期名は「コマ画像」に揃えた。
- 削除項目の表示を「削除」に短縮してDelを割当。確認・使用中参照の拒否・画像実体の保持・閉じる際のDraft保存は前回どおり。選択/生成状態の変更時にもEnabledを更新し、メニューを開く前のDelでも現条件を使う。空欄/未選択では削除と場面移動/コマ作成を無効にし、新規場面へ到達可能な状態を保つ。
- フォーム全体のキー処理を追加せず、FTreeだけに割り当てたポップアップのShortCutを使用する。名前・説明欄とフォームにはこのPopupMenuを割り当てない。読み取り参照：C:/Program Files (x86)/Embarcadero/Studio/37.0/source/vcl/Vcl.Controls.pas のTWinControl.IsMenuKey（対象コントロール→親階層だけのPopupMenu照会）、Vcl.Menus.pasのTPopupMenu.Create/TMenu.IsShortCut、Vcl.Forms.pasのTCustomForm.IsShortCut。VCLソースは無変更。
- 管理回帰に先頭3項目の順序、Del割当と入力欄/フォームへの非割当、メニュー未表示時の選択反映と実メニュークリックからの削除確認を追加。Delの実入力・文字削除・メニュー実表示は未実行。既知BRCC32レジストリ制限の条件が変わっていないためビルド再試行・昇格・別経路での回避はしない。構成検査67ユニット、git diff --check、対象PascalのUTF-8 BOMは確認済み。
- 既存の修正と未コミット差分を保持。起動中の作品・通常EXE・ユーザーデータは変更せず、音・commit/pushなし。

## 画像管理の右クリック操作・登録削除・閉じる保存（2026-10-17・実行検証待ち）

- ユーザーが前回変更を「うまくいった」と確認。今回の対象は画像管理。新規場面・派生画像・画像登録・人物/服装参照・台本読込を右クリックへ移し、既存の別位置背景・タイトル追加と登録削除を同じメニューへまとめた。空欄/未選択でも新規場面と台本読込を使える。Codex生成・中止・台本連続生成・生成プリセット（Codexの生成条件）はボタンに残す。キャラクター管理の既存操作ボタンは対象外として保持。
- 削除は場面名・派生を含む件数・割当コマ数・他画像からの参照数・台本対応数を表示し、明示確認の後だけ行う。否定ではStoreも行わず無変更。親場面は同じ親子ツリーの派生画像とまとめて登録を外す。割当コマ、外側のParentID/SourceID/SceneID参照、台本のuid対応が残る場合は理由を表示して停止する。台本対応が壊れている場合も停止。画像ファイルを物理削除しない。
- 削除したオブジェクトは背面の画像一覧更新まで画面内で所有して寿命を保つ。閉じた際に一覧を更新してから解放する。Undoの開始時Snapshotと旧画像を維持し、管理操作全体を1回のUndoへまとめる。使用中の参照を自動解除する機能や台本対応の解除UIは追加していない。
- 画像管理の「保存して閉じる」を廃止し、OnCloseQueryで入力をStoreした後、既存のAtomicWriteでDraft.jsonへ単独保存する。正式Project.jsonは従来のCtrl+S。保存失敗ではModalResultを解除して閉じるのを止め、入力と管理途中の変更を保つ。成功フラグと再入ガードで複数Close経路の二重保存を抑止し、外側FinishImageManagementは保存済みとして履歴/表示だけ更新する。生成結果や台本取込の従来の途中Draft保存は保持する。
- 回帰をSource/Tests/Management/ComicAssetDialogTests.pasへ追加。空欄メニューと実追加、最後の場面削除、確認キャンセル、親子削除/ファイル保持、コマ・外部場面・台本の参照保護、生成中の無効化、保存ロック失敗、再試行、再入/二重Close、Draft再読込、正式保存の区別を無音の確認応答で検証するコード。既存の管理回帰は保存済み経路へ合わせた。ただし今回コンパイル/実行していないためPASSではない。
- 前回BRCC32のレジストリ参照拒否（TestOutput/PanelImageLayout/debug.log、MSB4061/MSB4060）の実行条件は変わっていない。ビルドを再試行/昇格/別経路で回避せず、Delphi Debug/Release・実ダイアログ表示/操作・Undoを未検証として残す。構成検査は67ユニット、git diff --checkと対象PascalのUTF-8 BOMは確認。前回画像スナップ/標準コマ割り/台本関連の既存差分を保持し、起動中のユーザー作品、共有ライブラリ、通常EXE、resには変更を加えない。音、commit/push、不要な大容量データ作成/削除なし。

## 組込みコマ割りを5種から17種へ追加（2026-10-17）

- ユーザー依頼により既存標準5種を保持し、12種を追加。2コマ：上下・上大、上下・下大、左右・右大、左右・左大。3コマ：上2コマ＋下大、横長3段、右縦長＋左2コマ、右2コマ＋左縦長。4コマ：横長4段、横長＋2コマ＋横長。5コマ：2コマ＋横長＋2コマ。6コマ：標準3段。名称・自動サムネイル・一覧は従来の方式を使い、分類UIは追加しない。
- ComicLayouts.pasのSeedAdditionalLayoutsに矩形定義を分離。従来builtin-1〜5のID・順序・名前・形を保ち、新規builtin-6〜17を末尾へ追加する。コマ番号は追加順で、段内は右から左・段は上から下。段をまたぐ縦長は右列から左列へ読む。1200×1700、余白60、コマ間24の既存基準に従う。
- 起動時のSeedLayouts→LoadLayoutsと、BuiltIn以外だけをSaveLayoutsで保存する方式を維持。既存ユーザーは更新ビルドでアプリを再起動すれば標準17種＋保存済み自作分が一覧に出る。Presets/Layouts.jsonの削除・書換え・初期化は不要。標準は従来から名前変更/削除不可、自作分のID・編集済み内容・削除状態を標準追加で上書き/復活させない。現在起動中のアプリや通常EXEには未反映。
- Tools/CheckBuiltInLayouts.ps1で定数矩形を読み、17種のID/名前/配置の一意性、旧5種維持、範囲・最小寸法・重なりなし・24px間隔・右→左/上→下の読順・連番・組込の保存除外を静的に確認しPASS。証跡はTestOutput/BuiltInLayouts/structure.json。layout-structure.svgは番号付き構造見本で、実VCL描画のキャプチャではない。
- 既存自己検証の固定5/6件をBuiltInLayoutCount基準へ更新し、削除済み自作分が新標準と再読込しても復活しない回帰を追加。これらDelphi回帰は未コンパイル・未実行。前回のBRCC32レジストリアクセス拒否の実行条件は変わっていないため、ビルドを再試行/昇格/別経路で回避しない。実サムネイル・適用/保存/Undoも今回未検証で、ビルド可能後に指定Debug/Releaseで確認する。
- 構成検査66ユニット、git diff --check、対象PascalのUTF-8 BOMを確認。前回の画像リサイズ/スナップと台本関連の未コミット差分を保持。ユーザーのライブラリ・作品・起動中アプリ・通常EXEには触れず、音、commit/push、不要な大容量データ作成/削除なし。

## コマ枠リサイズと画像配置スナップ（2026-10-17・実行検証待ち）

- 最新指示により、コマ編集の枠リサイズで割り当て画像のページ上の位置・見た目の倍率を保つ。従来のCover倍率と手動Zoomの積を、押下時の画像範囲から補正する。単体・複数選択に適用し、枠の移動では従来どおり画像が追従する。画像UID・保存形式は変更しない。既存の枠スナップ（四辺・四隅、外枠・他コマ・間隔、最小寸法、Alt/設定OFF）を維持する。
- 追加指示により画像配置の移動・比率維持リサイズへ、所属コマの同じ側の端と中央へのスナップを追加。中央は画像中央とコマ中央。既存の8px相当許容距離を表示倍率/PPIで換算して共用し、コマ編集の設定とAlt解除に従う。リサイズの反対辺/固定点・比率・最小倍率を保つ。
- 吸着した軸だけ紫色点線を編集キャンバスに描く。ガイドはフォームの一時状態で、離す・取消・画面/選択変更で消す。Renderer・作品JSON・PNG出力へ追加しない。
- 新規計算はSource/Editing/ComicImageSnap.pas、回帰はSource/Tests/Editor/ComicImageLayoutTests.pas。四辺/四隅、拡大/縮小、4形状、表示ズーム1/2、最小寸法、画像の位置/倍率、複数選択、Undo/Redo、保存再読込、端/中央、比率/固定点、Alt/設定OFF、ガイド消去を検証するコードを追加した。ただし未コンパイル・未実行であり、PASSとは扱わない。
- 指定の ./build.ps1 -SelfTest -OutputDirectory 'TestOutput/Verified' を通常権限で実行したが、BRCC32タスクの初期化時にSystem.Security.SecurityException「要求されたレジストリ アクセスは許可されていません」で停止（MSB4061/MSB4060）。コンパイラ・自己検証へ到達せず、Release/通常版/実画面も未検証。ユーザー指示どおり昇格・別経路で回避せず停止。次回はビルド環境のアクセス制限が解決した後、指定DebugとReleaseを実行する。
- 静的な構成検査は66ユニットで成功。今回のログはTestOutput/PanelImageLayout/debug.log。開始時resを同Before/MangaMaker.resへ保持し、失敗後のSHA256一致を確認。既存の台本関連未コミット差分を保持し、ルートEXE・起動中の作品・他プロジェクトは更新しない。失敗ビルドが直下に生成したmanifest/vrcの2小ファイルはTestOutput/PanelImageLayout/FailedBuildへ移して保持。git diff --check成功。commit/push、音、不要な大容量データの作成/削除なし。

## I001へタイトルロゴときりたんの表示を追加（2026-10-17）

- ユーザー依頼「001にタイトルロゴを重ねたい、東北きりたんも表示」によりI001を扉絵へ更新。内蔵image_genで元I001と登録三面図を参照し、世界樹の商店街と横長2:1の画角を保ち、左にきりたん全身、右に「2万円のおにぎりと始まらない配信」の3行ロゴ、その下に「東北きりたん」を配置した。タイトルと名前の文字を目視確認。
- 今回のタイトル文字は明示依頼によるI001だけの例外。後続の本編コマには引き続き文字や吹き出しを焼き込まない。人物の外見は正式三面図を最優先とし、タイトル入りI001を次の画像の文字・構図基準として使わない。文字なし初登場画像はTestOutput/TitleI001/I001-before.pngと元の管理PNGに保持。
- assetID B46D556F-C1CB-4A96-80CE-B9DA7DD204BEを維持し、旧fileとexpectedContextを照合してregister_imageで更新。再照会した管理PNGと完成PNGのSHA256一致を確認。通常キャラライブラリ・台本・製品コード/EXEは無変更。アプリを開くGUI操作なし。
- 完成PNG・元画像・内蔵image_genの生成指示・開始時条件・登録結果・検証はTestOutput/TitleI001/{I001-title.png,I001-before.png,I001-title-prompt.txt,I001-context.json,I001-receipt.json,asset-after.json,verification.json}。

## I014から最終I049までCodexで順次制作（2026-10-17）

- 最新依頼「続けて順番に進めて、キャラの維持に注意」に従い、このチャットの内蔵image_genで背景B007〜B010とコマI014〜I049の計40点を1点ずつ生成・目視確認し、既存register_imageで送信した。アプリ側の連続生成は使用せず、sequenceActive=falseを維持。アプリを開くGUI操作はユーザーへ任せた。
- 開始時にアプリのread_scriptを再照会すると、現在の台本は12ページ・I049/D041まで完成していた。以前の「I046未完保留」は過去の状態であり、今回はI046以降も制作済み。現在の台本はTestOutput/CodexContinue/source.txtに取得。外部の元txtは変更していない。
- 主人公は毎回登録三面図を最優先にして、約2.8〜3頭身・大きな頭・短い胴と手脚・暗赤ボブ・両髪飾り・和服・帯・紺スカート・背中リボン・足袋と草履を確認。前画像は背景・動作・装備の補助資料として使用した。元上司/元部下は修正済みI007と初登場資料を参照。
- 店員はI014で短い茶髪・白三角巾・生成りシャツ・濃紺エプロンの中年女性として初登場し、後続でも参照。有名人はI027でアッシュグレーの短いウェーブ髪・茶目・丸眼鏡・青緑ジャケット・アイボリーニットの穏やかな男性として初登場し、I048/I049まで維持。配信者モブ二人はI044の黒短髪/四角眼鏡/からし色パーカーの男性、茶髪ポニーテール/紫シャツ/黒ヘッドホンの女性を後続参照にした。
- 後半の大型端末はI030/I031で薄い濃灰の横長タブレット・細い黒ベゼル・折り畳みスタンド・キーボードなしに固定。従来のスマホ/グリップ/ファーマイクは机に置いた一組だけ。I022の伝票に入った文字とI044/I045のバッグ付近に重複したマイク等は内蔵image_genで局所修正し、確認後に採用した。I044は取得済み画像を条件照合して更新、旧PNGも保持。
- 店の窓/客席/カウンター/藍色無地のれん/同方向の傾き/昼の光、食べかけのおにぎりと食器の経過を参照。主人公は実際には店を手伝わず、予備機材は見つからず、他人に借りず、有名人は催促せず、配信未開始の結末を維持。文字・セリフ・吹き出しは画像へ焼き込んでいない。
- 最終read_scriptで背景10＋コマ49の全59点completed、ready/waiting/deferredはすべて0。全管理画像が実在し、今回40点は生成PNGとアプリ管理PNGのSHA256一致を確認。末尾の「終了」や制作条件の箇条書きには既存パーサーの形式診断11件が残るが、画像項目の保留は0。原文を自動書換えしていない。
- 証跡・画像・各プロンプトはTestOutput/CodexContinue/。verification.json/csv、script-start.json/script-after.json、assets-after.json、各ID-context.json/-receipt.json/-prompt.txt、生成記録.txtを保持。Exchange.ps1は照会と送信のみで、Replace指定時も旧file/expectedContextを照合。生成・一貫性判断はこの会話が担当する。
- 通常キャラライブラリ・台本・製品ソース・EXEは今回変更なし。既存未コミット差分は保持。登録先は従来どおり作業データ/Draft。git diff --check成功。画像制作のみのためビルド/自己検証は実行していない。次はユーザーの確認後、既存のコマ配置・セリフ補完でページ制作を試す段階。吹き出し生成の実験は未着手。

## I010から3ページ目をCodexで制作（2026-10-17）

- ユーザーがI007〜I009の等身修正を承認し「I010から作業をしてみて」と依頼。まず自然な区切りとなる3ページ目のI010〜I013を、このチャットの内蔵image_genで1枚ずつ生成・目視確認し、既存register_imageで順にアプリへ送信した。
- 保留していたB006は、開始時と現在のgeneration_context/fingerprintが一致することを確認して先に登録。I010はB004の傾いた店舗外観へ3人が向かう引き、I011はB006店内で主人公だけが違和感を覚えて止まる3人構図、I012はB005で床・壁の傾きに気づく困惑、I013はB006で軽く平衡を崩し気分が悪くなる上半身中心の中景。
- すべて正式三面図を主人公の外見・約2.8〜3頭身の最優先参照にした。修正済みI007/I009は男性2人の服・鞄と持ち物の補助資料として使い、長い胴や脚へ戻らないことを確認。店内は左窓/客席・右カウンター/ケース・藍色のれん・同方向の傾き・昼の光を維持。文字・セリフ・吹き出し・コマ枠は焼き込んでいない。I012のコマ枠の斜め演出は後のページ編集で扱う。
- 各画像はexpectedContextとexpectedFileName空文字を照合して登録。UIDを保持。登録後にlist_assetsとread_scriptで再照会し、管理画像と生成PNGのSHA256一致を5件（B006/I010〜I013）で確認。現在19件取得済み、アプリ側のsequenceActive=false。アプリの自動生成やGUI操作は行っていない。通常キャラライブラリ、台本、アプリソース/EXEは変更していない。
- 証跡とプロンプトはTestOutput/CodexI010/{verification.json,assets-after.json,script-start.json,script-after.json,I010〜I013-context.json,-readable.txt,-prompt.txt,-receipt.json,I010.png〜I013.png,生成記録.txt}。B006の生成PNGとプロンプトは前回のTestOutput/CodexDirected。登録は従来どおり作業データ/Draftへ保存される。
- 次の場面は4ページ目。B007をB005から用意してI014の注文・会計へ進む。I046は未完保留のまま。ユーザーが画面を開く方針を維持する。

## I007以降の等身を登録三面図へ戻す（2026-10-17）

- ユーザー指摘：I007から等身が崩れているため、キャラ情報を再参照して正しく更新したい。取得済みコマはI009までなので、I007/I008/I009を修正対象とした。
- 登録された東北きりたん基本服装の正式三面図と、I006〜I009の実画像を目視比較。I007以降で頭に対して胴・腕・脚が伸びていることを確認。正式三面図の約2.8〜3頭身、大きな頭、短い胴と手脚を最優先にして、このチャットの内蔵image_genで各画像を編集した。元上司・元部下、背景、構図、台本の出来事を保ち、等身に必要な調整を行った。
- 修正I007を確認・送信した後、最新contextを取り直してI008、I009も順に修正・送信した。register_imageは旧fileとexpectedContextを照合。素材UIDと参照関係は維持し、旧画像もアプリ管理領域とTestOutput/CharacterProportionに保持。通常キャラライブラリ、正式三面図、台本原文、アプリソースやEXEは変更していない。
- 現在のユーザーアプリのmanifestはbridge-18916.json。ユーザーが開いた作品の画像管理へ3件の更新を反映済み。起動・作品を開く画面操作はしていない。登録は従来どおり作業データ/Draftに保存される。
- 検証：3件とも同じassetID、旧画像実在、新管理画像と修正PNGのSHA256一致を再照会で確認。証跡はTestOutput/CharacterProportion/{assets-before.json,assets-after.json,verification.json,I007〜I009-context.json,-before.png,-fixed.png,-prompt.txt,-receipt.json}。
- 以後は前コマをそのままキャラ体型の基準にせず、毎回正式三面図の頭・胴・脚の比率を優先して確認する。前コマは持ち物・動作・背景の連続性資料。B006は前ターンで生成済み・送信待ちのまま。

## Codex側で一貫性を確認して生成・送信する方針（2026-10-17・最新）

- ユーザー訂正：アプリに連続生成を一任する意味ではない。このチャットのCodexが台本・登録キャラ・背景・前コマを読み、生成画像を確認してからアプリへ送り、次へ進む。一貫性の判断はこの会話で保持する。
- アプリ側の連続生成をcancel_generationで停止し、sequenceActive=falseを確認。直前の連続処理で9件が完了し、元からの5件と合わせて14件取得済み。取得画像は保持した。今後start_script_generationを使わない。台本・進捗・生成条件の照会とregister_imageは既存連携を使えるので、今回の方針変更に追加UIやEXE差し替えは必要ない。
- このチャットの内蔵image_genでB006を生成し、B005との室内配置・画風・傾きの連続性を確認。PNGはTestOutput/CodexDirected/B006.png、プロンプトはB006-prompt.txt、開始時条件はB006-context.json。まだアプリへ登録していない。生成原本は保持。
- 最新ユーザー指示「開く作業はこっちでします」。アプリや作品を開く画面操作はユーザーへ任せ、こちらから追加のGUI操作をしない。対象作品がユーザー側で開かれた後、正しいmanifest・作品IDを再照会し、B006の開始時fingerprintと現条件を比較してから送信する。アプリのPIDは再起動で変わるので、Exchange.ps1の固定manifestをそのまま使わない。
- 外見・持ち物・店の配置の基準はTestOutput/CodexDirected/継続基準.txtに記録。補助Exchange.ps1は資料取得と送信のみで、画像生成・判断はしない。吹き出しまでの自動化は実験後に決める。以下のアプリ側連続生成の章は過去の試作経緯。

## 既存画像管理から台本順の連続生成（2026-10-17）

- 最新ユーザー依頼：画像整理からCodexで各種データを読み、画像生成→アプリへ送信→次のシーンを連続処理したい。吹き出しまで自動化するかは実験後に判断。専用台本画面を復活させず、既存画像管理に「台本の未取得画像を連続生成」を追加した。
- Model/Script/ComicScriptGeneration.pas が台本順の処理可能・取得済・背景/人物待ち・未完保留を計算。Workspaceの既存Codex生成・登録タイマーが各画像の採用後に次を選び直す。完成ファイルを飛ばして再開し、中止・管理画面終了・生成失敗・対象や条件変更で停止する。選択した背景・登録キャラに加え、説明のみの固有人物は初登場の取得画像を外見参照として渡す（集約した群衆定義は固定しない）。
- ローカル連携に read_script（原文＋進捗）、generation_context（既存生成と同じ情報・参照ファイル）、start_script_generation（limit指定可能）、cancel_generation を追加。Codexで直接生成した画像の register_image は任意 expectedContext で開始時の生成条件も照合できる。吹き出しの自動作成・焼込は追加せず、既存のセリフ入力候補を維持。
- Debug／Release各1835項目PASS、通常Releaseはエラー・警告・ヒントなし、通常版--self-testはexit2、64ユニットの構成検査とgit diff --check成功。別の隔離VCLホスト＋模擬Codexプロセスで実ワーカー通信/登録を通し、2枚上限、背景→人物、初登場参照、続きから再開、完了後の空実行、失敗、中止、生成中条件変更、前画像保持など19項目PASS。模擬応答は検証フォルダー内だけで使用し、実作品には登録していない。
- 実作品ID ACBD50A6-DA29-4ECC-A2B5-99FE2C0DBDCA（2万円のおにぎりと始まらない配信／第1話）を起動中のパイプから照会。既存4枚 B001/B002/I001/I004 を保持。内蔵imagegenで I002 を背景B002・東北きりたん三面図・I001を参照して生成し、開始時データが変わっていないことを再照会して、expectedFileName空文字付きで登録した。生成原本は保持。新しいアプリ管理画像は Images/271D25A5-8792-4B2B-8448-DBB64FC8A7A4.png。
- ユーザーの保存・メイン画面終了の返答を受け、プロセス終了を確認して通常EXEを差し替えた。SHA256 B074659650F8EAD42720BB908C395FAEA319EB49556EDBA383D689582FFD709B。直前EXEと開始時resをTestOutput/SceneSequence/Beforeへ保持。resは退避版とバイト一致で復元し、元からの差分を保持。commit/pushなし。
- 修正版を起動し、既存の作品読込UIで上記Project.jsonを開き、前回Draftの復元を選択してCtrl+Sで保存した。画像管理を開き、bridge-27024.jsonに start_script_generation を送り、I003から残り50件の実生成を開始済み。実連続処理でI003の生成・採用が完了し、B003へ自動移行したことをread_scriptで確認した。未完I046は別途1件保留。管理画面を閉じると停止する。ユーザーアプリやCodex本体を強制終了していない。
- 証跡：TestOutput/SceneSequence/{debug-current.log,release-tests.log,production.log,probe.log,live-plan.json,live-running.json,I002-context.json,I002-receipt.json,I002.png,verification.json}。元txtは無修正、SHA256は7C65524436EAE3E30E7874EC09A696BCF6444E2156498FCC6E8E8A9D2FD96C68を維持。通常キャラライブラリは読取のみ。GUI操作はcomputer-useスキル、画像生成はimagegenスキルを使用。

## 台本を既存画面へ補完する方針へ修正（2026-10-17）

- 最新ユーザー意図は、専用の台本UIを追加することではなく、既存の画像取得・セリフ入力で台本の内容を補うこと。従来の専用台本画面と逐次生成キューは取り除いた。以下の専用画面・修正版テキストへ置き換える案内は過去の経緯として読む。
- 画像管理に「台本を読み込む／補完」を追加し、背景・コマ画像を既存の親子ツリーへ取込む。名前・説明・参照キャラを補い、その後の取得は従来の画像生成／画像登録で行う。ファイルメニューも「台本を読み込む」へ変更し、既存画像管理へ接続した。
- 吹き出し右側の文字欄と既存の専用文字入力に、台本のセリフ候補を追加。配置画像のIDで絞り、選択で入力を補う。反映／確定は既存の動作を使い、選択だけで作品を上書きしない。
- 読込エラーを項目に所属させ、未完の項目だけを保留する。重複IDは両方の定義と依存先を保留し、無関係な項目は使える。台本全体の拒否は空・上限超過などだけとする。
- 元の V:/夢日記マンガ/2万円のおにぎりと始まらない配信.txt を無修正で検証し、背景10＋画像45の55項目、セリフ39件を取込めた。I046だけを保留。「客」「他の配信者たち」は集約したモブ定義から解決し、主人公の提供三面図は唯一の登録人物である東北きりたんの基本状態へ補う。複数の登録人物では勝手に割り当てない。
- 再読込で素材UID・取得画像・手動で修正した説明を保持する。保存失敗は素材と台本を復元し、取込は既存管理操作のUndoへまとめる。元のtxtを変更しない。通常のキャラライブラリも変更しない。
- 単独生成画面のコードと旧テストはTestOutput/ScriptIntegrated/Beforeへ退避し、現行回帰は既存画像管理・生成Snapshot・文字入力・保存整合を検証する内容へ置換した。試作用作品は TestOutput/ScriptIntegrated/Data/Projects/F13F454B-D184-40AB-B37D-2BE1B2864C1E/Project.json。今回の取込確認で新しい画像生成や外部送信はしていない。

- 台本IDを省略して読み直しても、作品に保持した前回の台本IDへ接続し、取得済み画像を重複作成しない。背景の指定を変更した場合は、自動補完したままの所属だけを更新する。手動変更した説明・名前・参照は保持する。

- 最終Win64 Debug／Releaseとも1825項目PASS（既存1798＋既存画面への台本補完27）。旧専用画面のテストを撤去し、部分読込・再読込・手動編集保持・背景所属更新・台本ID省略・保存失敗復元・既存生成Snapshot・両文字入力の仮確定を検証。通常Releaseもエラー／警告／ヒントなし、CLI自己検証拒否はexit2。通常EXEを更新し、新SHA-256は0AF63FF4A50B58CA97BA0921CC920E9C93A67AA06337E441D6FDEC5EBFC16442。開始時のMangaMaker.res差分は退避版からバイト一致で保持した。git diff --checkと63ユニットの構成検査は成功。証跡はTestOutput/ScriptIntegrated/verification.json、debug-current.log、release-current.log。commit/pushなし。

## 全文台本の読込エラー修正（2026-10-17）

- ユーザーが元の全文を開いた際のエラーを再現。732行の閉じ括弧不足、客・他の配信者たちの人物定義不足が開始を妨げていた。その他の背景待機は正常な依存待ちであり、書式の違いではない。前回の実生成確認は完結した1ページ版で、全文の入力整備が不足していた。
- 原本を保持し、TestOutput/ScriptTrial/2万円のおにぎりと始まらない配信_MangaMaker読込用.txt を作成。台本ID・東北きりたん／基本服装の主人公割当・脇役の明示定義を補う。未完の構図はコメントで原文を残し、I046を [生成：保留] とする。12ページ目・結末は創作していない。全文の専用読込検証はエラー・警告とも0件。
- 生成：保留／確認事項 を追加し、その項目だけを止めて独立した処理を続ける。生成：対象 に戻せば再開できる。保留指定でも不正な書式・未知の参照は自動的に許容しない。
- 台本画面の先頭に「開始を妨げる書式・参照エラー：件数」を表示し、補足と通常の順番待ちを区別。エラーがある間は開始ボタンを無効化し、修正後に有効化する。
- 今回は追加画像生成・実作品や通常キャラライブラリへの変更をしていない。修正版の開き方は TestOutput/ScriptTrial/全文修正版の開き方.txt。ユーザーへアプリ終了を依頼し、保存・終了済みとの返答を受領した。稼働中のユーザーアプリは強制終了しない。

- 最終Debug／Releaseとも1834項目PASS（保留・継続・開始ボタンを6項目追加）。全文修正版はエラー／警告0件。通常Releaseは警告・エラー・ヒントなし、通常版の自己検証拒否はexit2。ユーザーがメイン画面を終了した後にルートEXEを更新し、直前版をTestOutput/ScriptFix/Beforeへ保持。新SHA-256：9F01C87576F963C696BA5742617A8687F27F3B8A7477A1F31D96A28E47255922。証跡はTestOutput/ScriptFix/verification.json、debug.log、release.log。元台本SHA-256は7C65524436EAE3E30E7874EC09A696BCF6444E2156498FCC6E8E8A9D2FD96C68を維持。生成res差分は戻し、git diff --check成功。commit/pushなし。

## 台本読込・逐次生成の入口（2026-10-17）

- 最新ユーザー指示で製品実装へ着手。「コード変更不要」は以前の検討段階の方針。ファイルメニューに「台本から画像生成」を追加し、本文編集・登録人物割当・不足表示・開始／中止／再開を提供する。
- 専用台本の旧記法と角括弧記法、ページ見出し、暗黙の背景・セリフ画像、人物→表情の繰返し、心の声表記、複数行本文を読む。エラーは行番号付きで表示する。人物定義と登録名・服装・参照画像を照合し、画像ごとの変更を持ち越さない。説明のみの脇役は初登場画像も後続画像の参照に使う。
- 本編は依存順に1点ずつ既存の専用Codex通信で生成し、その後に使用する透明効果・オノマトペを生成する。使用しない素材は生成しない。セリフは生成指示から分離して一覧とコピーを提供する。
- 本文と台本ID／項目ID→UID・生成条件・画像ハッシュの対応を作品JSON内へ保存する。Draftの単一書込みが成功してから生成結果を採用する。完了済みは再利用し、条件変更・画像不足は明示指定で再生成する。既存画像の再生成ではUIDと旧ファイルを保持する。取消・遅延結果・保存失敗を検証する。
- モデル／読込／条件展開は Source/Model/Script、逐次処理はIntegration、画面はDialogs、自己検証はTests/Managementへ配置する。同階層プロジェクトは今回は参照・変更していない。
- ユーザー指定の実台本は V:/夢日記マンガ/2万円のおにぎりと始まらない配信.txt。末尾は11ページ目I046の構図行で途切れている。原本を変更せず、完結している1ページ目をTestOutput/ScriptTrialへ切り出した。主人公は東北きりたん／基本服装へ割当。通常キャラライブラリは読み取りだけで、専用Dataに参照画像をコピーして使用した。
- 実通信でB001とI001の2点を生成・自動登録し、文字・吹き出しなし、背景の継続と東北きりたんの配置を目視確認した。作品は TestOutput/ScriptTrial/Data/Projects/9EE89D37-98A6-4571-A415-4503AAFDB8E5/Project.json。試作継続は同フォルダー上位の 開始手順.txt／Start-ScriptTrial.ps1。残りの画像を自動で追加生成していない。
- 入力ひな型を試作版2へ短縮。旧サンプルと旧記法は保持して読める。今回の操作・省略規則・素材・制限は Samples/ScriptWorkflow/台本読込の使い方.txt を現行の入口とする。旧「移動先での開始手順」「読込確認結果」は2026-10-16の履歴。
- 今回は生成中の台本画面が編集を占有する。セリフD&D・自動ページ配置・編集中の裏生成・自動品質判定は未実装。ページ見出しは構成案として保持し、コマ割り・吹き出し配置は人間が担当する。実台本の続きを補完する作業も行っていない。


- 最終Win64 Debug／Releaseとも1828項目PASS（従来1798＋台本30）。依存順、参照展開、画像別上書き、未使用素材、実ダイアログ読込と人物割当、重複・途切れ・未定義参照、保存再読込、完了再利用、UID維持の再生成、中止、Draftロック失敗と再送を検証。通常Releaseもエラー・警告・ヒントなし。構成は64ユニットで1500行／8ユニット制限を満たす。ログは TestOutput/ScriptBuild/。Debug fixtureは80038487b0594eac9219013da24e1c35、Releaseはeb360a25bed4433ab4fbf043b157adc1。VCLの項目一覧とボタンをオフスクリーン描画で確認したが、メモ欄の描画はそのキャプチャ方式では確認できていない。物理操作・実モニターDPIの確認は未実施。

- 通常起動用MangaMaker.exeを検証済み通常Releaseへ更新。旧版はTestOutput/ScriptTrial/Beforeへ保持。新SHA-256は74C9F92D4FECA99C9903370269F4DFBA422F056C4D66DDE607AB0871D4AD8F37。通常版の自己検証拒否と検証版の引数ガード計3件は終了コード2。生成されたres差分は元へ戻し、ソース差分に生成物を含めない。git diff --check成功、commit/pushなし。

## 台本テンプレートの作成・読込検討（2026-10-16）

- **別環境での再開入口：`Samples/ScriptWorkflow/移動先での開始手順.txt`。** テンプレートを実環境の人物・状態名へ合わせ、最初は背景B001と人物画像I001だけを既存機能で試す。アプリの「台本読込」操作はまだない。サンプルをビルドしても読込機能は増えない。コード変更不要の指示は継続中。
- 移動時は本note・READMEと `Samples/ScriptWorkflow/` 全体を持っていく。2026-10-16の確認時点では文書は未コミット、同フォルダーは未追跡のため、別PCでgit pullするだけでは届かない。`TestOutput` の検討用Python/JSONは再開の必須ファイルではなく、実行済みの確認結果はサンプル側のtxtに保持している。移動先の実キャラ・状態の画像データは別途必要。
- コード修正不要というユーザー方針を維持し、`Samples/ScriptWorkflow/` に台本テンプレート・記入済みサンプル・記法と進め方・読込確認結果を作成した。製品ソース、EXE、既存作品は変更していない。
- `*` は新規背景、`**` は既存背景から移動先の背景、`***` は背景と人物から人物入り画像。参照省略時は直前の背景を使用。人物の基本状態に各画像だけの上書きを適用し、履物・靴下・持ち物も生成指示へ展開する。
- コマ割り・画像配置・吹き出し作成は人間が担当。台本のセリフを一覧から吹き出しへD&Dする案。本編画像の完成後、編集と並行して少数の効果・オノマトペを全てAIで生成する案。素材はIDで共通定義し再利用する。文字描画によるオノマトペ加工は将来候補。
- `TestOutput/ScriptWorkflow/inspect_script.py` は検討用の使い捨て読込処理。実ファイルから背景2点・人物入り画像4点・セリフ5件・共通素材2点（計4回参照）を抽出し、背景参照・人物状態の非持越し・改行・セリフと生成指示の分離等11件PASS。展開済み指示は同フォルダーの `sample-plan.json`、検査結果は `checks.json`。通常のpython入口は実行できず、Codex同梱Pythonで実行した。
- 検証範囲は台本から作業計画を組み立てるところまで。人物ライブラリ照合、実AI生成、画像登録、裏生成と編集の同時実行、セリフD&Dは未実施。台本読込・一括待ち行列・永続UID対応/再開・セリフ一覧/D&D・編集と素材登録の調整は追加実装が必要。現行パイプには生成開始や効果素材の専用actionがない。
- 次はユーザーが台本と読込結果を確認し、実装範囲を決める。製品コード変更がないためビルド・自己検証は実行していない。commit/pushなし。

## 素材画面への管理・分類・生成統合（2026-10-14）

- 「効果素材」の直下へ編集可能なグループ一覧を追加。右クリックで追加・削除、ダブルクリックで名前編集、Enter確定・Esc取消。選択グループだけを表示する。未分類は固定で、グループ削除時は素材を未分類へ戻す。素材の右クリックにグループ移動（現在所属のチェック）、名前変更、登録削除を用意した。登録削除でもPNGと配置済み作品を保持する。
- 素材管理へのボタンと配置素材の削除ボタンを撤去。設定メニューの効果素材もこの画面へ切替。旧管理ユニットは既存回帰用に保持し、製品画面からは呼び出さない。横4:縦3・右側名称、コマへのD&D、キャンバスからの配置削除を保持。
- ExplorerからPNGを一覧へドロップすると管理先へコピーし、選択グループへ登録。元画像は保持。分類は共通 `Effects/Groups.json` にIDで保存し、保存失敗時は分類を復元。不正な分類ファイルを読み込んだ場合は書込みを停止する。
- 下部にメモ・Codexへ送信・中止・状態表示を追加。短い指示へ透明背景・4:3・漫画用の効果条件を補い、既存Codex通信から完了画像を管理先へ受けて自動登録。送信から完了・エラーまで再送と分類変更を停止。内側のダイアログ中は登録を待ち、閉じる際は所有要求だけを中止する。生成画像にアルファ透明部分がなければ登録せずエラー表示する。
- 共有素材の分類・登録を `Source/Materials`、通信をIntegration、UI・ドロップをControls、検証をTests/Managementへ分離。日本語の責務・判断理由コメント、UTF-8 BOMを確認。59ユニットで1500行/8ユニット上限と `git diff --check` はPASS。既存のARM設定・サンプル編集差分を保持。
- 読み取り参照元：`D:\DelphiProg\test\Gareton\Lib\ListBoxEdit\ListBoxEdit.pas`（相対 `../../test/Gareton/Lib/ListBoxEdit/ListBoxEdit.pas`）。元ファイルは変更せず、ローカルコピーに編集可否・確定時の再入防止・暗色表示への対応を加えた。
- ユーザー提示の起動時EInvalidOperationは、親ウィンドウ設定前のリスト更新が原因。パネルのコンストラクターへ親を渡し、子コントロール作成・更新より前に設定した。部分初期化時の破棄と遅延イベントも保護。検証用の失敗プロセスだけをパス照合後に終了し、ユーザーアプリは強制終了していない。
- 最終Win64 Debug/Releaseとも1798項目PASS（追加35項目）。分類の永続化・保存失敗復元・日本語名編集・移動メニュー・ネイティブファイルドロップ・二重送信防止・エラー再送・不透明画像拒否・登録一回性・中止・破損分類・素材削除を確認。96/144 PPIのVCL描画で表示を目視確認。最初の追加144PPI検証は描画時の自動DPI復帰で失敗したため、既存検証と同じく拡縮後に自動調整を止めた。狭い表示では少なくとも1行が収まり、分類と重ならない条件を確認。物理D&D・実モニターDPI・今回の実画像生成は未検証。生成は模擬応答で検証し、外部生成・送信を行っていない。
- 通常Releaseも警告・エラー・ヒントなし。専用データで通常フォームの起動とWM_CLOSEによる終了を確認後、通常起動用ルートEXEを更新した。SHA-256：`39342AF19CA2882F622F718BB8F396A82C4533E437E39A66E772E3D2AA9B6A3B`。通常Releaseの検証・計測DCUは0件。同梱サンプルEXE・ZIPは更新していない。
- 今回のTestOutputの3145ファイル（約1.0GiB）を削除済み。履歴登録済みサンプルの全ファイルは削除直前のハッシュ一致を確認した。自己検証ソース・通常EXE・ユーザー作品は保持。commit/pushなし。

## 効果一覧の横並び・4:3サムネイル（2026-10-14）

- 漫画効果の素材一覧を、左に112×84px（96PPI基準）の4:3サムネイル、右に名称という配置へ変更。名称は右側で折返し、長い場合は省略表示。行高を116→104pxとし、画像一覧に近い配置へ揃えた。透明素材の市松下地と選択枠、D&D操作を保持。
- 変更はWorkspaceEffectsの一覧描画とWorkspaceUIの行高。日本語コメントで固定比率と描画失敗時の継続理由を説明。既存のサンプル編集差分とプロジェクト設定変更を保持。
- 開始時のdprojではMangaMakerSelfTestの条件グループが欠落しており、自己検証が通常版として終了していた。検証用defineと検索パスの条件グループだけ復旧し、ARM設定など既存差分は戻していない。
- Debug自己検証1763項目PASS。通常Releaseもビルド成功、両構成ともエラー/警告/ヒントなし。96/144 PPIの実VCLキャプチャで横並び・4:3・名称を目視確認。物理マウス・実モニターDPI操作の確認ではない。
- ユーザーが通常版を保存・終了した後、ルートMangaMaker.exeを検証済み通常Releaseへ更新。SHA-256はC94066986798F7CAD5DD587943F5E983E5936508FDF870F0E92AD27A4D195495。Releaseには検証・計測DCUを含まない。
- 今回生成したTestOutputの680ファイル（約278.6MiB）も削除済み。サンプル全ファイルは削除前後のハッシュ一致を確認し、同梱EXEやZIP・作品データは上書きしていない。commit/pushなし。

## 検証成果物の削除（2026-10-14）

- ユーザー指示により、検証用プロジェクト・EXE・データ・画像・ログ・退避コピーを含む `TestOutput` 全体、生成DCUの `Win64`、ルートの `MangaMaker.rsm` を削除。合計14,883ファイル、約6.411GiB。
- 通常の読込履歴は `D:\Users\take6\MangaMaker\Presets\RecentProjects.json`。登録済みサンプルは `Samples/FeatureTour-20261014/Project/Project.json` で、削除した検証フォルダーには依存しない。
- `Samples` 一式と配布ZIP、同梱App EXE、通常起動用のルートEXE、ソース、Tools、ビルドに必要なdpr/dproj/res、通常の人物・設定・履歴データを保持。保護対象141ファイルのSHA-256が削除前後で一致し、作品・Draft・人物のファイル参照21件とコマの画像ID参照を確認した。
- 継続開発に必要な `Source/Tests` の回帰ソースとビルドスクリプトは保持。今回はビルド・自己検証を再実行せず、検証生成物を作り直していない。commit/pushなし。
- 以下の過去記録にある `TestOutput` 配下の証跡・退避版・EXE・仮作品は削除済みで、再開時の現存成果物として使わない。過去の検証結果は記録として残す。次のビルドは `build.ps1` で新しく生成する。

## コメント・肥大化防止の規約

参照元：`../MapRaku/note.md` の「コメント・肥大化防止の規約」（2026-10-14確認）。同文書には元の参照元として `D:\DelphiProg\test\Backupn\note.md` が記載されている。今回はMapRakuの規約本文を読み取り参照した。

- 日本語コメントは目的・判断理由・制約を説明し、コードの言い換えは避ける。各ユニット冒頭に責務を記載する。中止・上書き・例外・スレッド間通信では安全上の理由を説明する。
- MangaMakerはユーザー指示（2026-10-14）により、**1ユニット1500行程度**を目安とする。参照元の300～500行から緩和した。1メソッド50行、1フォルダー5～8ユニットは引き継ぐ。責務が混ざれば行数に関係なく分割を検討する。行数合わせの細分化や将来用の空フォルダーは作らない。
- 日本語を含むPascalはUTF-8 BOM付き。Win64 Debug／Releaseの警告・エラー0と `git diff --check` を確認する。

`Tools/CheckSourceLayout.ps1` は1ユニット1500行・1フォルダー8ユニットを上限としてビルド前に確認する。行数以内でも責務の混在や長いメソッドをレビューする。50行を超えるメソッドを、行数だけのために細切れへ分割しない。

## 規約の受領とコメント整理（2026-10-14）

- ユーザー指定の `../MapRaku/note.md` から必要な規約と参照元を記録。ユニット行数は最新ユーザー指示の1500行程度へ変更。MapRaku側には変更しない。
- 52ユニットの冒頭に日本語の責務コメントを記載。英語の判断理由を日本語に整理し、取消、上書き、保存失敗、スレッドからの結果受渡しについて理由を補足。分離後のフォームとWorkspaceが同じ状態を参照する設計も説明する。
- テストをTests/Editor（6ユニット）・Management（3）・Support（2）へ配置し、全フォルダー8ユニット以内。構成チェックは1500行/8ユニットでPASS。通常版と検証版のWin64 Debug/Release計4構成をビルドし、エラー/警告/ヒントなし、git diff --checkも成功。全53 Pascalソース（52ユニット＋dpr）のコメント・空白を除くトークンが変更前と一致し、UTF-8 BOMとユニット責務コメントを確認。dpr比較では明示したテスト参照2パスの移動だけを補正。アプリの実行処理は変更していないため、直前の1763項目回帰を重複実行していない。証跡と変更前ソースはTestOutput/Comments-20261014/に保存。通常EXE・サンプル・ZIP・実作品・MapRakuは更新せず、commit/pushなし。

## ソース構成整理（2026-10-14）

- 開始時main/1d92e78。前回の画像配置D&D変更（README/MainForm/noteの未コミット差分）を保持。開始時MainFormは5977行、Source/Shellに33ユニット。開始時MainFormをTestOutput/Structure/Before/へ保存。
- MainFormから自己検証をSource/Testsの共通fixture・実行入口・9分野へ分離。テスト専用のTComicTestFormを使用し、製品フォームからSmokeTestとアイコン検証専用状態を削除。チェック内容と実行順序を保持。
- Workspaceの8ユニットへ画面構築/パイプ要求/画像生成/表示操作/幾何編集/マウス編集/吹き出し/漫画効果を分離。フォームは状態・所有権・イベント入口を持ち、非公開の実装ヘルパーへ委譲。ヘルパーに別の状態を持たせず、フォームのprotectedメンバーを参照。publicへ状態を公開していない。製品メソッドの欠落0件。MainFormは1299行。
- 既存32ユニットをModel/Rendering/Editing/Text/Dialogs/Integration/Export/Diagnostics/Controlsへ移動し、Git blobで内容が元と一致することを確認。検索パスとプロジェクト参照を更新。他プロジェクトは参照・変更していない。
- build.ps1の-SelfTestだけでMANGAMAKER_SELFTESTを定義し、Testsの検索パスとコードを組み込む。通常版はテストコードを含まず--self-testをexit2で拒否。通常ReleaseのテストDCU/計測DCUは0件。4つの既存CLIガードと通常版の拒否1件はexit2、生成0件。
- Tools/CheckSourceLayout.ps1をビルド前に実行。通常1000行/フォーム1500行/1フォルダー12ユニットの上限をAGENTS/READMEへ記載。現構成52ユニットでPASS。自己検証をフォームへ戻すことや巨大includeへの退避は避ける。
- 分離直後のDebugは1763項目PASS（TestOutput/d6e2ab81100c44bfb4aa0b267a6f4e60/、Structure/Debug-before-comments.log）。最終Debug/Releaseの同時実行は180秒の待ち時間上限に達し、大画像PNGが1ページ数分かかった。今回所有のRelease検証プロセスだけをパス照合後に停止して逐次検証へ変更（部分fixture 35de52a966014e8690fb45838bf1422fは保持）。残したDebugは65339f183bdf41f3a0960419a8fbc3bbで1763項目PASSへ完走。Releaseの単独実行は180秒以内に終了し、edeb2a063cb5498e923c35f94d2ee024で1763項目PASS（Structure/Release-sequential.log）。最終Debug/Releaseの全項目を確認済み。通常Releaseビルドは成功、エラー/警告/ヒントなし。
- この区切りではコメントルールの受領待ちだった。受領後の対応は冒頭の「規約の受領とコメント整理」を参照。通常EXE・サンプル・ZIP・実作品はこの構成整理では更新していない。commit/pushなし。
- 証跡：TestOutput/Structure/。Structure-verification.json、CLI-results.json、Production-Release.log、最終Debug/Releaseログ、開始時ソース、整理用スクリプトを保持。

## 画像配置をD&Dに統一（2026-10-14）

- 画像一覧からコマへのD&Dに統一。配置/解除ボタン、倍率コンボ、重複する画像管理ボタン、一覧ダブルクリック配置を削除。画像管理は既存メニューを使用し、画像のパン/比率維持8点拡縮を保持。
- 画像配置欄の上部を188→56px（96PPI基準）へ縮小し、画像一覧を132px相当広げた。
- コマの右クリックメニューに「画像の割り当て解除」とDel表記を追加。右クリックしたコマを対象にし、空白では開かない。キャンバスのDelも同じ解除処理へ接続。文字入力/画像一覧/別編集モードでは画像解除を実行しない。
- D&Dは事前選択なしでドロップ先を選択し、配置後はキャンバスへフォーカス。人物未登録の既存作品でも画像D&Dを許可。解除は素材を保持し、配置状態をUndoで復元する。
- 最終Win64 Debug/Releaseとも1763項目PASS、エラー/警告/ヒントなし。D&D対象/一覧拡張/ダブルクリック無効/右クリック対象切替/解除とUndo/Del/一覧フォーカス時の保持を確認。検証画像で一覧拡張を目視。実物理マウスでの確認は未実施。Debug fixture: TestOutput/68ea8448e72240cc8876cacac9365d4d/、Release: TestOutput/0b4cb2f4763f4541a0f58988194c68b3/。ログ: TestOutput/ImageDnd-Debug-final.log、TestOutput/ImageDnd-Release.log。最初のDebugは進捗ファイルの実行中読み取りによる共有競合で停止したため、終了後に読む方法で再実行して完走。失敗fixtureも保持。直下MangaMaker.exeを検証済みReleaseへ更新し、旧EXEはTestOutput/ImageDnd-Before/へ保存。サンプル同梱版/ZIPは今回更新していない。commit/pushは行っていない。

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

ページ管理の差分更新時にAPI宣言を読み取り参照したDelphi 37.0標準ソース（変更なし）:

- `C:/Program Files (x86)/Embarcadero/Studio/37.0/source/vcl/Vcl.StdCtrls.pas`
- `C:/Program Files (x86)/Embarcadero/Studio/37.0/source/vcl/Vcl.Controls.pas`
- `C:/Program Files (x86)/Embarcadero/Studio/37.0/source/rtl/common/System.Hash.pas`

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
