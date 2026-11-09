# Jira Cloud 実環境構築ログ

`index.html` のモックで示した設計を、実際の Jira Cloud（`silverhomuradev.atlassian.net`）上に構築した記録です。
すべて REST API を使う PowerShell スクリプトで行い、何度実行しても同じ結果になるように作っています。

## 安全方針

- 構築対象は `DEMO` プロジェクトだけです。業務で使用中の `SUP` と `SCRUM` には手を加えません。
- サイト全体に影響する設定（Automation のグローバルルール、カスタムフィールドのグローバルコンテキスト）は使わず、すべて `DEMO` プロジェクトの範囲内で設定します。
- 認証情報は環境変数 `JIRA_SITE` / `JIRA_EMAIL` / `JIRA_API_TOKEN` から読み込みます。トークンをリポジトリや画面に出力することはありません。

## 実行方法

```powershell
.\jira\01-create-project.ps1
.\jira\02-fields-and-request-types.ps1
.\jira\04-allow-self-approval.ps1   # -Restore で元の設定（本人承認を禁止）に戻す
```

Step 3・4 の一部（ポータルのフォーム、SLA、Automation）は公開 API がないため管理画面で設定しています。

スクリプトは日本語を含むため UTF-8（BOM 付き）で保存しています。Windows PowerShell 5.1 は BOM のない UTF-8 ファイルを正しく読めないためです。

## 進捗

| Step | 内容 | スクリプト | 状態 |
|---|---|---|---|
| 1 | JSM プロジェクト `DEMO` を作成（社内向けサービスデスクテンプレート） | `01-create-project.ps1` | 完了 |
| 2 | カスタムフィールド・画面配置・リクエストタイプ | `02-fields-and-request-types.ps1` | 完了 |
| 3 | ポータルのフォーム項目配置・ポータルグループ | 管理画面（手作業） | 完了 |
| 4 | SLA・承認者を設定する Automation・本人承認の許可 | 管理画面 ＋ `04-allow-self-approval.ps1` | 完了 |
| 5 | 別ユーザー（顧客）が申請し、承認者が承認する流れの確認 | 管理画面（顧客追加）＋ ポータル | 完了 |

### Step 1 の結果

- プロジェクト `DEMO`（id 10002）、サービスデスク id 2
- テンプレートで作成された課題タイプ: IT Help / Service Request / **Service Request with Approvals**（承認待ちステータスを含む）/ Task / Sub-task
- 初期状態のリクエストタイプ（購入・出張・入社手続きなど）は、次の Step でデモ用の申請種別に置き換えます

### Step 2 の結果

**カスタムフィールド**（フィールド ID は `fields.json` に保存し、以降のスクリプトから参照します）

| モックの項目 | Jira フィールド | 型 |
|---|---|---|
| 品目 / 案件名 | 件名（Summary） | 標準 |
| 購入理由 / 概要 | 説明（Description） | 標準 |
| 金額 | `[DEMO] 金額（税込・円）` | 数値 |
| 媒体 | `[DEMO] 媒体` | 選択リスト（Web / 印刷 / 動画） |
| 尺 | `[DEMO] 尺（秒）` | 数値 |
| 希望納期 | `[DEMO] 希望納期` | 日付 |
| 対象システム | `[DEMO] 対象システム` | 選択リスト（Slack / GitHub / Jira） |
| リポジトリ名 | `[DEMO] リポジトリ名` | テキスト |
| 利用開始日 | `[DEMO] 利用開始日` | 日付 |

**リクエストタイプ**（課題タイプは `Service Request with Approvals`）: 備品購入申請 / 制作依頼 / アカウント発行申請。
テンプレートに含まれていたサンプルのリクエストタイプは削除しました。ただし `Emailed request` はメールチャネルの既定リクエストタイプのため削除できず、残しています。

**影響範囲の制御で分かったこと**

- 現在の Jira Cloud では、カスタムフィールドのグローバルコンテキストを変更・削除できません（[CHANGE-3019](https://developer.atlassian.com/changelog/#CHANGE-3019)）。API で試すと 400 エラーになります。
- そのため、次の 2 つで影響範囲を `DEMO` に限定しています。
  1. 選択肢などの設定は、`DEMO` 専用に作ったコンテキストだけに持たせる
  2. フィールドは `DEMO` 専用の画面（`DEMO: Jira Service Management Screen`）にだけ配置する。`SUP` / `SCRUM` の画面には表示されません
- フィールド名に `[DEMO]` を付け、サイト全体のフィールド一覧でもデモ用だと分かるようにしています。

**API で設定できないこと**: リクエストタイプごとに、ポータルのフォームへどの項目を表示するか（項目配置と必須設定）は公開 API で設定できないため、管理画面で行います（次の Step）。

### Step 3 の結果（管理画面で設定）

公開 API で設定できない部分を、`DEMO` のプロジェクト設定画面（Request types → Request form）で設定しました。
設定後、`/rest/servicedeskapi/servicedesk/2/requesttype/{id}/field` で反映を確認しています。

| リクエストタイプ | ポータルのフォーム項目（上から順） |
|---|---|
| 備品購入申請 | 件名（必須） / 金額（税込・円）（必須） / 説明 |
| 制作依頼 | 件名（必須） / 説明 / 媒体 / 尺（秒） / 希望納期 |
| アカウント発行申請 | 件名（必須） / 対象システム / 利用開始日 / リポジトリ名 |

- 3 つのリクエストタイプを、既存のポータルグループ `Need approval` に入れ、ポータルに表示されるようにしました（設定前は「Hidden from portal」）。
- `Emailed request` はメール受付専用のため、ポータルには表示しないままにしています。
- 備品購入申請の金額は、ポータル上の表示名を `[DEMO]` なしの「金額（税込・円）」にしています。

### Step 4 の結果（管理画面で設定）

**SLA**（カレンダーは 24/7。モックと同じく 24 時間で計算）

| SLA | 開始 | 一時停止 | 停止 | 目標 |
|---|---|---|---|---|
| 承認までの時間 | 「Waiting for approval」に入る | - | 「Waiting for support」に入る / 解決状況が設定される | 8h |
| 解決までの時間 | 「Waiting for support」に入る | 「Waiting for customer」の間 | 解決状況が設定される | 24h |

テンプレートにもともとあった `Time to first response` / `Time to resolution` は残しています。

**Automation `[DEMO] A1 承認者設定＋部長承認判定（10万円以上）`**（適用範囲は DEMO のみ）

1. トリガー: 作業項目の作成
2. 条件: `issuetype = "Service Request with Approvals"`
3. アクション: 承認者（Approvers）を設定
4. 条件: `cf[10062] >= 100000`（金額が 10 万円以上）
5. アクション: 内部コメント「部長承認の対象です」を追加

実行ユーザーは既定の「Automation for Jira」だと DEMO の閲覧権限がなくエラーになるため、サイト管理者のユーザーにしています。権限スキームを変えると SUP にも影響する可能性があるので、そちらは変更していません。

**動作確認**（API でテスト申請を作成）

- DEMO-1（金額 150,000 円）: 承認者が設定され、部長承認のコメントが付いた。承認までの時間の SLA（8h）が計測中
- DEMO-2（金額 30,000 円）: 承認者が設定され、コメントは付かなかった

**本人承認の許可**（`04-allow-self-approval.ps1`）

テンプレートのワークフローは「申請者本人と担当者は承認できない」（`exclude: reporter, assignee`）設定です。サイトのユーザーが 1 人だけのため、このままでは承認者が申請者本人として除外され、誰も承認できませんでした。
DEMO 専用のワークフロー（DEMO 以外のプロジェクトで使われていないことをスクリプトで確認）に限り、除外対象を担当者だけにしています。`-Restore` を付けて実行すると元に戻せます。

- この変更は新しく作られた申請から適用されます。変更前に作った DEMO-1 / DEMO-2 は承認者が 0 人のまま残っています
- DEMO-3（金額 5,000 円）で承認から次の状態までを確認しました: 承認すると「Waiting for support」に進み、承認までの時間の SLA が完了し、解決までの時間の SLA（24h）が始まりました

画面操作の録画（GIF）: `step4a_demo_sla_setup.gif`（SLA 設定）、`step4b_demo_approver_automation.gif`（Automation 作成）

### Step 5 の結果（申請者と承認者が別の人の流れ）

申請者 `silverhomurallc@gmail.com`（ポータルのみ使う顧客）、承認者 Silver Homura LLC（`takashi_ichimasa@silverhomuradev.com`）で、実際の運用に近い流れを確認しました。

**顧客の追加**

1. DEMO →「Customers」→「Add customers」でメールアドレスを追加します。招待メールが送られます
2. 追加されるのはポータル専用の顧客アカウント（accountId が `qm:` で始まる）で、Jira のライセンスは使いません

**つまずいた点: 招待リンクでパスワードを設定できない**

- 招待メールのリンク先で「Set password」を押しても、画面が何も変わりませんでした
- 開発者ツールで確認すると、`setpassword?jwt=...` の通信が **401** を返していました。招待リンクに含まれるトークンが無効になっていたのが原因です。「Resend Invite」を押すたびに、それまでのリンクは使えなくなります
- 解決方法: 招待リンクは使わず、ポータル（`/servicedesk/customer/portal/2`）のログイン画面で「Forgot your password?」から再設定メールを受け取り、パスワードを設定しました。設定すると、Customers 画面の状態が「Invited」から「Active」に変わります

**動作確認**（DEMO-4: 備品購入申請、金額 150,000 円、gmail のアカウントからポータルで申請）

| 確認内容 | 結果 |
|---|---|
| 承認者が Automation で設定されるか | Silver Homura LLC が設定された |
| 10 万円以上で部長承認のコメントが付くか | 内部コメントが付いた（顧客には表示されない） |
| 申請直後の SLA | 承認までの時間（8h）が計測中 |
| takashi が承認した後 | 「Waiting for support」に進み、承認までの時間の SLA が完了（違反なし）、解決までの時間の SLA（24h）が始まった |

現在は本人承認を許可した設定のままです。申請者と承認者が別の人であれば、`04-allow-self-approval.ps1 -Restore` で本人承認を禁止する元の設定に戻しても承認できます。

画面操作の録画（GIF）: `step5_demo_gmail_request_takashi_approval.gif`（takashi による承認）
