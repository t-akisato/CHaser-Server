# -*-coding: utf-8 -*-
#
# unofficial CHaser Server on Ruby
#
# Copyright (c) 2018 Tadakatsu Akisato
#
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
#
# ※公式のサーバーと同一の動作を保証するものではありません。

require 'socket'
require 'pp'
require 'optparse'

# 接続情報
host = "localhost"
port = [2009,2010]

# マップ用定数
M_FLOOR = 0
M_CHARA = 1
M_BLOCK = 2
M_ITEM = 3

# 変数
@s = []
@socket=[]
@name = []   # 名前
th =[]      # スレッド 管理用
mapfilename='map01.map'   # マップファイル名
@map = []                 # マップ
@bg_map = []              # 背景色マップ
@turn_max = 200           # 最大ターン数
@chara_x = []             # キャラ位置
@chara_y = []
# @chara=[".","X","#","$", "C", "H"]
@chara=[". ","X ","# ","$ ", "C ", "H "] # 表示用キャラセット
@chara_z=["・","X","■","＄", "Ｃ", "Ｈ"] # 表示用キャラセット(全角モード）
@ch_color=[7,7,7,3,6,5] # 表示色コード
@score = [0,0]          # スコア
@turn= -1               # ターン数 (表示の関係で -1 から ^^;
life=[1,1]              # 生死 ( GetReadyで返す1バイト目 )
wait = 0.5              # 表示速度のウェイト（秒）
step_count = 0          # ポーズモード用カウンタ
values = Array.new(10)  # 送信データ用領域

#
# 関数定義
#
#
# 画面表示
def disp(map)
  old_color = 999
  old_bg = 999
  map_d = Marshal.load(Marshal.dump(map)) # map を map_d に複製
  2.times do |i|
    if map_d[@chara_y[i]][@chara_x[i]] == M_BLOCK then   # プレイヤー位置にブロックがあったら死んでるので
      @bg_map[@chara_y[i]][@chara_x[i]] = @ch_color[i+4] # 背景色をキャラの色にしてブロックを表示
    else
      map_d[@chara_y[i]][@chara_x[i]] = i + 4 # 普通にキャラを表示
    end
  end
  printf("\e[0;0H\e[0m\e[40m") # カーソルを左上に
  printf("\e[37m[[\e[36mC\e[35mH\e[37maser(unofficial)]]  Turn:%4d\n", @turn_max - @turn - 1)
  printf("\e[36mCOOL\e[37m(%s):%3d     \e[35mHOT\e[37m(%s):%3d\n", @name[0], @score[0], @name[1], @score[1])

  # マップを表示
  @map_size_y.times do |y|
    @map_size_x.times do |x|
      if old_color != @ch_color[map_d[y][x]] then # 色が変わる時だけエスケープシーケンスを表示
        old_color = @ch_color[map_d[y][x]]
        printf("\e[3%dm",@ch_color[map_d[y][x]])
      end
      if old_bg != @bg_map[y][x] then # 背景色が変わる時だけエスケープシーケンスを表示
        old_bg = @bg_map[y][x]
        printf("\e[4%dm",@bg_map[y][x])
      end
      printf("%s",@chara[map_d[y][x]]) # キャラを表示
    end
    puts # 改行
  end
  printf("\e[37m\e[40m") # 色を戻す
end

# 背景色を設定
def set_bg(bg_x, bg_y, c)
  if bg_x >= 0 && bg_x < @map_size_x && bg_y >= 0 && bg_y < @map_size_y then
    @bg_map[bg_y][bg_x] = c
  end
end

# 背景色マップをクリア
def clear_bg()
  @map_size_y.times do |y|
    @map_size_x.times do |x|
      @bg_map[y][x] = 0 # 黒
    end
  end
end

# 周辺情報の背景色をセット
def nearby_bg(x,y)
  c = 2 # 緑
  9.times do |j|
    bg_x = x+(j%3)-1
    bg_y = y+(j/3).to_i-1
    set_bg(bg_x,bg_y,c)
  end
end

#マップの値を取得
def get_map_value(x,y,c)
  if x < 0 || y < 0 || x >= @map_size_x || y >= @map_size_y then
    return M_BLOCK # 範囲外はブロックを返す
  end
  if x == @chara_x[1-c] && y == @chara_y[1-c] && @map[y][x] != M_BLOCK then
    return M_CHARA # 敵キャラ
  end
  return @map[y][x]
end

# 周辺情報を values にセット
def get_nearby_information(values, i)
  values[0] = 1
  9.times do |j|
    values[j+1] = get_map_value(@chara_x[i]+j%3-1,@chara_y[i]+(j/3).to_i-1,i)
    #    set_bg(@chara_x[i]+j%3-1,@chara_y[i]+(j/3).to_i-1, 2) # 背景色(2=緑)もセット
  end
end

# look で返す値を values にセット
def get_look_information(values, x, y, c)
  values[0] = 1
  9.times do |i|
    values[i+1] = get_map_value(x+i%3-1, y+(i/3).to_i-1, c)
    set_bg(x+i%3-1, y+(i/3).to_i-1, 1) # 背景色(1=赤)もセット
  end
end

# サーバーのIPアドレスを取得
def my_address
  udp = UDPSocket.new
  # クラスBの先頭アドレス,echoポート 実際にはパケットは送信されない。
  udp.connect("128.0.0.0", 7)
  adrs = Socket.unpack_sockaddr_in(udp.getsockname)[1]
  udp.close
  adrs
end

#--------------------------------------------------------------------------------
#
# メイン
#
#

# オプション読み込み
#pp ARGV
option = {}
OptionParser.new do |opt|
  opt.on('-z', 'zenkaku mode') {|v| option[:z] = v}
  opt.on('-m file', 'map file') {|v| option[:map] = v}
  opt.on('-p [val]', 'pause mode') {|v|
    if v == "look" then
      option[:p_look] = true
    elsif v == "search" then
      option[:p_search] = true
    else
      option[:pause] = (v == nil) ? 1 : v.to_i
      option[:p_look] = nil
      option[:p_search] = nil
      step_count = option[:pause]
    end
  }
  opt.on('-w time', 'wait(second)') {|v| option[:wait] = v.to_f}
  opt.parse!(ARGV)
end
#pp ARGV
#pp option
#pp option[:pause]
#gets
if option[:z] then # 全角モード
  @chara = @chara_z
end

if option[:wait] then # 表示ウェイトを設定
  wait = option[:wait]
end

# マップファイル名を設定
if option[:map] then
  mapfilename = option[:map]
end
printf("map:[%s]\n", mapfilename)

# マップ読み込み
begin
File.open(mapfilename,"r") do |mapfile|
  map_line = 1
  mapfile.each_line { |line|
    line.chomp!
    line_body = line.sub(/^.:/,'')
    case line[0] # １文字目で判別
    when "N" # 名前
      @map_name = line_body
      puts "name:" + @map_name
    when "T" # ターン数
      @turn_max = line_body.to_i
      puts "turn:" + @turn_max.to_s
    when "S" # マップサイズ
      map_size_s = line_body.split(',')
      @map_size_x = map_size_s[0].to_i + 2
      @map_size_y = map_size_s[1].to_i + 2
      #      printf("map x,y:%d,%d\n",@map_size_x,@map_size_y)
    when "D" # マップデータ
      line_body = '2,' + line_body + ',2' # マップの左右にブロックを配置

      @map[map_line] = line_body.split(',')
      @map[map_line].each_with_index { |data, idx|
        @map[map_line][idx] = data.to_i
      }
      map_line += 1
    when "H" # HOT初期位置
      chara_s = line_body.split(',')
      @chara_x[1] = chara_s[0].to_i + 1 # マップ周辺にブロックを表示するので、位置をずらす
      @chara_y[1] = chara_s[1].to_i + 1
    when "C" # COOL初期位置
      chara_s = line_body.split(',')
      @chara_x[0] = chara_s[0].to_i + 1
      @chara_y[0] = chara_s[1].to_i + 1
    end
  }
end # マップ読み込み終了
rescue => error
  puts error.message
  exit
end

# マップの上下にブロックを配置
@map[0] = Array.new(@map_size_x)
@map[@map_size_y - 1] = Array.new(@map_size_x)
@map_size_x.times do |x|
  @map[0][x] = M_BLOCK
  @map[@map_size_y - 1][x] = M_BLOCK
end

# gets

# 背景色用マップ領域確保
@bg_map = Array.new(@map_size_y).map{Array.new(@map_size_x,0)}

puts "IP address:" + my_address # IPアドレスを表示
puts "接続を待っています。"

# マルチスレッドで接続待機
2.times do |i|
  th[i] = Thread.new(i) { |i|
    # ポートを開放
    @s[i] = TCPServer.open( port[i] )
    @s[i].set_encoding 'utf-8'

    # 接続待ち
    @socket[i] = @s[i].accept

    # 名前を取得
    @name[i] = @socket[i].gets.chomp!
    #    puts @name[i].encoding

    printf("%s(port:%d) 接続しました。\n",@name[i].force_encoding("UTF-8"),port[i])
  }

end

# 接続終了を待つ
th.each {|t| t.join}

printf("\e[2J") # 画面クリア
disp(@map)  # 画面表示

# Enterでゲーム開始
printf("Enterでゲーム開始します。")
$stdin.gets

# ゲーム開始
@turn_max.times do |turn|
  @turn = turn
  2.times do |i|
    # GetReadyを受信
    @socket[i].puts("@")
    code = @socket[i].gets.chomp
    # チェック
    if /gr/ !~ code then
      life[i] = 0
      printf("通信エラー(GetReady=>%s)", code)
      break
    end

    clear_bg()
    nearby_bg(@chara_x[i], @chara_y[i])

    disp(@map)
    printf("\e[0J")
    puts @name[i] + "のターン。"
    # puts code

    clear_bg()
    # 周辺情報を取得
    get_nearby_information(values,i)
    # 周辺情報を送信
    @socket[i].puts(values.join)

    # メソッドを受信
    code = @socket[i].gets.chomp
    printf("[%s] ", code)
    # チェック
    if /[wpls][udrl]/ !~ code then
      life[i] = 0
      puts "通信エラー"
      break
    end

    #マップ変更の処理
    case code[0]
    when "w"
      old_x = @chara_x[i]
      old_y = @chara_y[i]
      case code[1]
      when "u"
        @chara_y[i] -= 1
      when "d"
        @chara_y[i] += 1
      when "r"
        @chara_x[i] += 1
      when "l"
        @chara_x[i] -= 1
      end
      if get_map_value(@chara_x[i],@chara_y[i],i) == 3 then # Item ゲットだぜ！
        @score[i] += 1
        @map[@chara_y[i]][@chara_x[i]] = 0
        @map[old_y][old_x] = 2
      end
      get_nearby_information(values,i) # 周辺情報
    when "p"
      case code[1]
      when "u"
        @map[@chara_y[i]-1][@chara_x[i]] = 2
      when "d"
        @map[@chara_y[i]+1][@chara_x[i]] = 2
      when "r"
        @map[@chara_y[i]][@chara_x[i]+1] = 2
      when "l"
        @map[@chara_y[i]][@chara_x[i]-1] = 2
      end
      get_nearby_information(values,i) # 周辺情報
    when "l"
      case code[1]
      when "u"
        get_look_information(values, @chara_x[i],@chara_y[i]-2,i)
      when "d"
        get_look_information(values, @chara_x[i],@chara_y[i]+2,i)
      when "r"
        get_look_information(values, @chara_x[i]+2,@chara_y[i],i)
      when "l"
        get_look_information(values, @chara_x[i]-2,@chara_y[i],i)
      end
    when "s"
      case code[1]
      when "u"
        9.times do |d|
          values[d+1] = get_map_value(@chara_x[i],@chara_y[i]-(d+1),i)
          set_bg(@chara_x[i],@chara_y[i]-(d+1),1)
        end
      when "d"
        9.times do |d|
          values[d+1] = get_map_value(@chara_x[i],@chara_y[i]+(d+1),i)
          set_bg(@chara_x[i],@chara_y[i]+(d+1),1)
        end
      when "r"
        9.times do |d|
          values[d+1] = get_map_value(@chara_x[i]+(d+1),@chara_y[i],i)
          set_bg(@chara_x[i]+(d+1),@chara_y[i],1)
        end
      when "l"
        9.times do |d|
          values[d+1] = get_map_value(@chara_x[i]-(d+1),@chara_y[i],i)
          set_bg(@chara_x[i]-(d+1),@chara_y[i],1)
        end
      else # 通信エラー
        life[i] = 0
      end
      #      values[0] = 1
    end

    # 表示用文字列
    str1 = case code[0]
    when "w"
      "Walk"
    when "p"
      "Put"
    when "l"
      "Look"
    when "s"
      "Search"
    end
    str1 += case code[1]
    when "u"
      "Up"
    when "d"
      "Down"
    when "r"
      "Right"
    when "l"
      "Left"
    end

    #生死判定
    2.times do |j|
      if get_map_value(@chara_x[j],@chara_y[j],j) == M_BLOCK then #  ブロックと重なってたらアウト
        life[j] = 0
      end
      if get_map_value(@chara_x[j],@chara_y[j]-1,j) == M_BLOCK && # 四方がブロックならアウト
      get_map_value(@chara_x[j],@chara_y[j]+1,j) == M_BLOCK &&
      get_map_value(@chara_x[j]+1,@chara_y[j],j) == M_BLOCK &&
      get_map_value(@chara_x[j]-1,@chara_y[j],j) == M_BLOCK  then
        life[j] = 0
      end
    end
    values[0] = life[i]

    # 周辺情報を送信
    @socket[i].puts(values.join)

    # "#"を受信
    code1 = @socket[i].gets.chomp
    printf("%12s => %s\n",str1, values.join)
    sleep(wait/2)
    disp(@map)
    #printf("\e[0J")
    step_count -= 1

    # pauseオプションの処理
    if option[:pause] != nil && step_count <= 0 ||
    option[:p_look] && code[0] == "l" || # lookごとにポーズ
    option[:p_search] && code[0] == "s" then # search ごとにポーズ

      printf("\n\nsure?")
      n = gets.chomp
      if n != "" then # 何か入力あればポーズのステップ数を変更
        option[:pause] = (n.to_i < 1) ? 1 : n.to_i
      end
      step_count = option[:pause] != nil ? option[:pause] : 0
    end

    sleep(wait/2)

    if life[0] == 0 || life[1] == 0 then
      break # どちらかアウトならループ抜ける
    end
  end # COOL/HOTのループ
  if life[0] == 0 || life[1] == 0 then
    break # どちらかアウトならループ抜ける
  end
end # ターン数のループ
disp(@map)
printf("\n\n")
# 勝敗判定
if life[0] == 0 && life[1] == 0 then
  winner = 2 # 両者アウトなら引き分け
elsif life[0] == 0 && life[1] == 1 then
  winner = 1 # HOTの勝ち
elsif life[0] == 1 && life[1] == 0 then
  winner = 0 # COOLの勝ち
elsif @score[0] == @score[1] then
  winner = 2 # スコアで引き分け
elsif @score[0] > @score[1] then
  winner = 0 # スコアでCOOLの勝ち
else
  winner = 1 # でなければ HOTの勝ち
end

# 勝敗表示
case winner
when 0
  puts "\e[36mCOOL\e[37m(" + @name[0] +") WIN !!"
when 1
  puts "\e[35mHOT\e[37m(" + @name[1] +") WIN !!"
when 2
  puts"DRAW !!"
end
printf("\e[0J")

# 強制終了
2.times do |i|
  if life[i] != 0 then
    # GetReadyを受信
    @socket[i].puts("@")
    code = @socket[i].gets.chomp

    # 周辺情報を送信
    @socket[i].puts("1000000000")

    # メソッドを受信
    code = @socket[i].gets

    #マップ変更の処理

    # 周辺情報を送信
    @socket[i].puts("0000000000")

    # "#"を受信
    code = @socket[i].gets
  end
end

@s[0].close
@s[1].close

