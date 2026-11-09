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
```

## 進捗

| Step | 内容 | スクリプト | 状態 |
|---|---|---|---|
| 1 | JSM プロジェクト `DEMO` を作成（社内向けサービスデスクテンプレート） | `01-create-project.ps1` | 完了 |

### Step 1 の結果

- プロジェクト `DEMO`（id 10002）、サービスデスク id 2
- テンプレートで作成された課題タイプ: IT Help / Service Request / **Service Request with Approvals**（承認待ちステータスを含む）/ Task / Sub-task
- 初期状態のリクエストタイプ（購入・出張・入社手続きなど）は、次の Step でデモ用の申請種別に置き換えます
