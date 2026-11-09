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
```

スクリプトは日本語を含むため UTF-8（BOM 付き）で保存しています。Windows PowerShell 5.1 は BOM のない UTF-8 ファイルを正しく読めないためです。

## 進捗

| Step | 内容 | スクリプト | 状態 |
|---|---|---|---|
| 1 | JSM プロジェクト `DEMO` を作成（社内向けサービスデスクテンプレート） | `01-create-project.ps1` | 完了 |
| 2 | カスタムフィールド・画面配置・リクエストタイプ | `02-fields-and-request-types.ps1` | 完了（ポータルの項目配置は未着手） |

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
