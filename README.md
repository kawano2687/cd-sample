# cd-sample

## クラスタ管理者向け事前準備

このセクションでは、ハンズオン環境を準備するために必要な作業を **"クラスタ管理者向け"** に説明します。ハンズオンを実施する利用者・開発者の方は次のセクションにお進みください。

### 概要

このセクションでは、ハンズオンに必要な設定を適用します。

下記の Operator のインストール・設定を行います。

* OpenShift GitOps Operator (ArgoCD) のインストール: ハンズオン用 CD ツール
* Git リポジトリ (Gitea) のインストール: ハンズオン用 Git リポジトリを格納。各ユーザーの開発用プロジェクトにリポジトリをデプロイ。
* Web Terminal Operator のインストール: ユーザのオペレーション用。セッションタイムアウトの時間を延長。

また、GitHub Actions からアクセスするための設定を行います。

* GitHub Actions Secrets の設定: OpenShift クラスタとイメージレジストリへのアクセス情報

デモ環境用に下記のプロジェクトを作成します。また、Argo CD コントローラーからアプリケーションを管理できるように専用のラベル (`argocd.argoproj.io/managed-by=openshift-gitops`) を追加します。

* demo-develop（開発環境）
* demo-staging（ステージング環境）
* demo-production（本番環境）

**注:** このデモでは admin ユーザーで全操作を実行するため、個別のユーザー作成や RBAC 設定は不要です。

### 設定手順

クラスタ管理者アカウントでログインし、下記の手順を実行します。

```bash
# 管理者アカウントでログインしていることを確認
$ oc whoami
admin

# 準備用ディレクトリ移動
$ cd cd-sample/preparations/

# Gitea にミラーリングするマニフェストリポジトリの情報を環境変数に設定
# これらの変数は prepare.sh が Gitea API でリポジトリを移行する際に使用されます

# マニフェスト用リポジトリ（本リポジトリ）
$ export CONFIG_REPO_NAME=cd-sample
$ export CONFIG_REPO=https://github.com/kawano2687/cd-sample.git

# 設定スクリプトを実行（引数不要）
$ sh prepare.sh
```

認証情報は ID は `gitea`、パスワードは `openshift` となります。