# CHaser-Server
CHaser Server on Ruby (unofficial)

Rubyで書いた、U-16プログラミングコンテストの競技「CHaser」のサーバープログラムです。
Windowsのコマンドプロンプト、Macのコンソールなどで、Rubyがインストールされている環境で動作します。

ruby chsr.rb -h

で簡単なヘルプが表示されます。

ruby chsr.rb

でmap01.mapというマップファイルを読み込んで起動します。マップファイルを指定するには 

ruby chsr.rb -m ファイル名

とします。

ruby chsr.rb -w 数字

で画面表示のウェイトを指定できます（単位は秒）。デフォルトは 0.5 です。

ruby chsr.rb -p [数字]

でポーズモードで起動します。指定したターンごとにEnterの入力を待ちます。数字を省略すると1ターン毎になります。

ruby chsr.rb -z

で全角モードで起動します。Windowsのコマンドプロンプト以外では表示が崩れるようです。

起動後、ポート2009(COOL)、2010(HOT)にクライアントプログラムを接続して、エンターキーでゲーム開始になります。

公式のサーバーと同一の動作を保証するものではありません。

This software is released under the MIT License, see LICENSE.

（このソフトウェアは、MITライセンスのもとで公開されています。LICENSEを見てください。） 
