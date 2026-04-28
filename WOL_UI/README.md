# WOL CLI UI

Markdown のマシン一覧を読み取り、CLI 上で対象を選んで Wake-on-LAN を送信する Ruby ツールです。

## 目的

- 機器一覧を Markdown で一元管理する
- CLI から名前で対象を選んで WOL を送信する
- 構成は YAML で切り替え可能にする

## 想定ユースケース

- NAS、検証機、リモートワーク用 PC などを起動したい
- 既存の機器台帳 (Markdown) をそのまま使いたい
- 複数ネットワークセグメント向けに送信先を変えたい

## 要件定義

### 必須要件

- `config.yaml` を読み込む
- 指定 Markdown ファイル内のテーブルから「マシン名」「MAC アドレス」を抽出する
- 抽出結果を画面表示してユーザー入力を受け付ける
- 選択された 1 台に対して WOL (Magic Packet) を送信する

### 推奨要件

- 名前の部分一致検索
- 選択ミスを防ぐ確認プロンプト
- 送信成功/失敗の表示
- 無効な MAC アドレスの入力検証

## 入力ファイル仕様

### 1. `config.yaml`

最小例:

```yaml
machine_list_path: "./machines.md"
broadcast_ip: "192.168.1.255"
port: 9
```

キー仕様:

- `machine_list_path`: マシン一覧 Markdown のパス
- `broadcast_ip`: WOL 送信先ブロードキャストアドレス
- `port`: WOL 送信先 UDP ポート (通常 7 または 9)

### 2. `machines.md`

テーブル例:

```md
| name        | mac               | note        |
|-------------|-------------------|-------------|
| dev-pc-01   | AA:BB:CC:DD:EE:01 | Main desk   |
| nas-lab-01  | AA:BB:CC:DD:EE:10 | Lab storage |
```

抽出ルール:

- 列名は厳密一致でなくてもよい (例: `name`, `machine`, `host` を名前候補)
- MAC は `AA:BB:CC:DD:EE:FF` 形式を優先 (ハイフン区切りも許容して正規化可)

## CLI 振る舞い仕様

1. `config.yaml` を読み込む
2. Markdown テーブルを解析して候補一覧を表示
3. ユーザーが番号または検索語を入力
4. 対象確定後に WOL 送信
5. 結果を表示して終了

表示イメージ:

```text
[1] dev-pc-01   AA:BB:CC:DD:EE:01
[2] nas-lab-01  AA:BB:CC:DD:EE:10
Select machine (number/name): 2
Send WOL to nas-lab-01? [y/N]: y
WOL sent: nas-lab-01 (AA:BB:CC:DD:EE:10)
```

## エラーハンドリング方針

- `config.yaml` が見つからない: ファイルパスを表示して終了
- Markdown が読めない/テーブルがない: 解析対象が見つからない旨を表示
- MAC が不正: 該当行を警告し、候補から除外
- 送信失敗: 例外内容を表示して終了コード非 0

## 実装方針 (Ruby)

想定ファイル構成:

```text
bin/
	wol_ui
src/
	wol_ui/
		config.rb
		machine_parser.rb
		wol_sender.rb
		cli.rb
```

役割:

- `config.rb`: YAML 読み込みと値検証
- `machine_parser.rb`: Markdown テーブル解析と MAC 正規化
- `wol_sender.rb`: Magic Packet 生成と UDP 送信
- `cli.rb`: 画面表示と入力制御
- `bin/wol_ui`: エントリーポイント

## 開発セットアップ

```bash
bundle install
```

起動想定 (実装後):

```bash
bundle exec ruby bin/wol_ui
```

## テスト観点

- YAML の必須キー欠落時に適切なエラーになるか
- Markdown の列順が変わっても抽出できるか
- MAC 正規化が期待通りか
- WOL 送信データ長が 102 byte になるか

Magic Packet のデータ長:

$$
6 + 16 \times 6 = 102
$$

## 現在のステータス

このリポジトリは初期段階で、README は仕様定義として先に整備しています。実コードはこれから追加する前提です。

## 次の実装タスク

1. `bin/wol_ui` の作成
2. `src/wol_ui` 配下のモジュール分割実装
3. サンプル `config.yaml` と `machines.md` の追加
4. 最低限の単体テスト追加
