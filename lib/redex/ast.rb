# frozen_string_literal: true

module Redex
  # AST ノードに関するヘルパーや定義を置くプレースホルダモジュールです。
  #
  # 現状、Parser はハッシュ形式の AST を返します。
  # 将来的にノードクラスを導入する場合の拡張ポイントとしてファイルを用意しています。
  module AST
    # ドキュメント的に使われるノードタイプの一覧（シンボル）を列挙します。
    NODE_TYPES = %i[number ident binary let const].freeze
  end
end
