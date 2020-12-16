class GraphsController < ApplicationController
  require 'benchmark'
  include Math
  before_action :require_user_logged_in
  
  def index
    if params[:plot_no].present?
      @plot_no = params[:plot_no].to_i
    else
      for i in 1..8
        if @map = current_user.maps.find_by(plot_no: ((i-9)*-1))
          @plot_no = ((i-9)*-1)
        end
      end
    end
        
    @result = Benchmark.realtime do
      # 基準日
      @time =Time.now
      if params[:date].nil?
        @map = current_user.maps.find_by(plot_no: @plot_no)
        @time =Time.new(@time.year, @time.month, @time.day, 0, 0, 0, "+09:00")
      else
        @map = current_user.maps.find_by(plot_no: params[:plot_no])
        @time = params[:date] + " 00:00:00 +0900"
        @time = Time.parse(@time)
      end
  
      #基準日の日の出、日の入り、南中を求める
      @APPEARANCE = 0
      @MERIDIAN = 1
      @DISAPPEARANCE = 2
      #日の出
      @appearance_time = getSunPositionHourAngle(@APPEARANCE,@time,@map.longitude,@map.latitude)
      @dsp_appearance_time = @appearance_time.strftime("%H:%M:%S")
      
      @azimuth_altitude_a = getSunInfo(@appearance_time,@map.longitude,@map.latitude)
      #南中
      @meridian_time = getSunPositionHourAngle(@MERIDIAN,@time,@map.longitude,@map.latitude)
      @dsp_meridian_time = @meridian_time.strftime("%H:%M:%S")
      
      @azimuth_altitude_b = getSunInfo(@meridian_time,@map.longitude,@map.latitude)
      #日の入り
      @disappearance_time = getSunPositionHourAngle(@DISAPPEARANCE,@time,@map.longitude,@map.latitude)
      @dsp_disappearance_time = @disappearance_time.strftime("%H:%M:%S")
      
      @azimuth_altitude_c = getSunInfo(@disappearance_time,@map.longitude,@map.latitude)
  
      # 基準日内で一分ごとにカウントしていく
      #@AzimuthAndAltitude = Struct.new(:azimuth, :altitude)
      #@azimuth_altitude = @AzimuthAndAltitude.new()
      #@altitude_data = Array.new(1440).map{Array.new(2,0)}
      #@azimuth_data = Array.new(1440).map{Array.new(2,0)}
      #@t_azimuth_data = Array.new(1440).map{Array.new(2,0)}
      
      @Hours_data = Array.new(1441)
      @Minutes_data = Array.new(1441)
      @altitude_data = Array.new(1441)
      @azimuth_data = Array.new(1441)
      @real_azimuth = Array.new(1441)
      
      @t_azimuth_data = Array.new(1441)
    
      for i in 0..1440
        @timeconut = @time + (i * 60)
        @azimuth_altitude = getSunInfo(@timeconut,@map.longitude,@map.latitude)
        #@altitude_data[i][0] = @timeconut.strftime("%H:%M")
        #@altitude_data[i][1] = @azimuth_altitude.altitude
        #@azimuth_data[i][0] = @timeconut.strftime("%H:%M")
        #@azimuth_data[i][1] = sin(DEG2RAD(@azimuth_altitude.azimuth)) * 90.0
        @t_azimuth_data[i] = @timeconut
        #@t_azimuth_data[i][1] = @azimuth_altitude.azimuth
        
        @Hours_data[i] = @timeconut.hour
        @Minutes_data[i] = @timeconut.min
        @altitude_data[i] = @azimuth_altitude.altitude.floor(2)
        @real_azimuth[i] = @azimuth_altitude.azimuth.floor(2)
        @azimuth_data[i] = (sin(DEG2RAD(@azimuth_altitude.azimuth)) * 90.0).floor(2)
        # 初期化
        #@data[i] = { "time" => @timeconut, "altitude" => @azimuth_altitude.altitude, "azimuth" => sin(DEG2RAD(@azimuth_altitude.azimuth)) * 90.0 }
      end
      gon.year = @time.year
      gon.month = @time.month
      gon.day = @time.day
      gon.hours = @Hours_data
      gon.minutes = @Minutes_data
      gon.altitude = @altitude_data
      gon.real_azimuth = @real_azimuth
      
      gon.azimuth = @azimuth_data
    end
  end
  
  private
  
  def getSunPositionHourAngle(position_type,time,lambda_data,phi)
    #λ:経度を代入
    @lambda = lambda_data

    #Φ:緯度を代入
    @phi = phi
    
    #E:地平線の伏角
    @E = GetHorizonDip(0)

    #R:大気差
    @R = 0.585556
    
    #時刻変数 d
    @d = Float::NAN

    #天体位置による制限
    case position_type
      when 0
        @d = 0.25#((gcnew TimeSpan( 6, 0, 0))->TotalSeconds) / 86400
        @accuracyRange = 0.00005
      when 1
        @d = 0.50#((gcnew TimeSpan( 12, 0, 0))->TotalSeconds) / 86400
        @accuracyRange = 0.00002
      else
        @d = 0.75#((gcnew TimeSpan( 18, 0, 0))->TotalSeconds) / 86400
        @accuracyRange = 0.00005
    end
    
    #T:経過ユリウス年の算出
    @T = ElapsedTimeByJulian(time,0)
    
    #λ:黄経, β:黄緯により、黄道座標系を生成
    @EclipticCoordinate = Struct.new(:lambda, :beta)
    @sun_ecliptic_longitude = GetSunEclipticLongitude(@T)
    @ecliptic_coordinate = @EclipticCoordinate.new(@sun_ecliptic_longitude,0)
    
    #r:距離の算出
    @r = GetSunDistance(@T)
    
    #ε:黄道傾角の算出
    @ecliptic = GetEcliptic(@T)
    
    #赤道座標を算出
    @EquatorialCoordinate = Struct.new(:delta, :alpha)
    @equatorial_coordinate = EquatorialCoordinate(@T,@ecliptic,@ecliptic_coordinate)
    
    @diff = 1
    
    @accuracyRange = 0.00005
    while !(@diff.abs <= @accuracyRange) do
      #S:太陽の視半径
      @S = GetSunVisualRadius(@r)
      
      #Π:視差
      @pi = GetSunParallax(@r)
      
      #k:出没高度
      @k = Float::NAN
      @twilight_types = 0
      case @twilight_types
        when 0
          @k = -@S - @E - @R + @pi
        when 1
          @k = -6.0 - @E + @pi
        when 2
          @k = -12.0 - @E + @pi
        else
          @k = -18.0 - @E + @pi   
      end

      #Θ:恒星時を算出
      @theta = GetSiderealTime(@T,@d, @lambda, 9)
      
      #tk:出現時の時角を算出
      case position_type
        when 0
          @tk = GetHourAngle(@k, @equatorial_coordinate.delta, @phi)
          #負側の時角とする
          if 0 <= @tk
            @tk *= -1
          end
        when 1
          @tk = 0
        else
          @tk = GetHourAngle(@k, @equatorial_coordinate.delta, @phi)
          #負側の時角とする
          if 0 > @tk
            @tk *= -1
          end
      end
        
      #天体の時角tを算出
      @t = @theta - @equatorial_coordinate.alpha
      
      #理論値との差分を求める
      @dt = @tk - @t
      @dt = ToHourAngleRange(@dt)
      
      #繰り返し計算の補正値を算出
      #360.0は太陽の24時間あたりの時角の増加量
      @deltaD = @dt / 360.0
      @d += @deltaD
      
      @diff = @deltaD
    end
    
    #計算結果を変換
    # 後で追加 if 
    
    #時間に変換
    @ts = ToTimeSpan(@d)
    
    #時角をDateTimeに変換
    @dt = time + @ts
    
    #高度、方位角を算出
    #AzimuthAndAltitude aaa(t, phi, equatorialCoordinate->Delta, equatorialCoordinate->Alpha)
  end
  
  def getSunInfo(time,lambda_data,phi)
    #λ:経度を代入
    @lambda = lambda_data

    #Φ:緯度を代入
    @phi = phi
  
    #T:経過ユリウス年の算出
    @d = ((time.hour * 3600.0) + (time.min * 60.0) + time.sec) / 86400.0;
    @T = ElapsedTimeByJulian(time,0)
    
    #λ:黄経, β:黄緯により、黄道座標系を生成
    @EclipticCoordinate = Struct.new(:lambda, :beta)
    #@GetSunEclipticLatitude = GetSunEclipticLatitude
    @sun_ecliptic_longitude = GetSunEclipticLongitude(@T)
    @ecliptic_coordinate = @EclipticCoordinate.new(@sun_ecliptic_longitude,0)
    
    #ε:黄道傾角の算出
    @ecliptic = GetEcliptic(@T)
    
    #赤道座標を算出
    @EquatorialCoordinate = Struct.new(:delta, :alpha)
    @equatorial_coordinate = EquatorialCoordinate(@T,@ecliptic,@ecliptic_coordinate)

    #Θ:恒星時を算出
    @theta = GetSiderealTime(@T,@d, @lambda, 9)
      
    #天体の時角tを算出
    @t = @theta - @equatorial_coordinate.alpha
  
    #高度、方位角を算出
    @AzimuthAndAltitude1 = Struct.new(:azimuth, :altitude)
    @azimuth_altitude1 = @AzimuthAndAltitude1.new()
    @azimuth_altitude1 = GetAzimuthAndAltitude(@t, @phi, @equatorial_coordinate.delta, @equatorial_coordinate.alpha)
    return @azimuth_altitude1
  end
  
  
  #地平線の伏角(E)
  def GetHorizonDip(altitude)
		if (0.0 >= altitude)
			return 0.0
		else
			return 0.0353333 * sqrt(altitude)
		end
  end
  
  #T:経過ユリウス年の算出
  def ElapsedTimeByJulian(time, time_dif)
    
    #K':2000/1/1 12:00からの経過日数
    @Y = time.year - 2000
    @M = time.month
    @D = time.day
    
    #1月, 2月は前年の 13月, 14月
    if 2 >= @M
      @Y -= 1
      @M += 12
    end
    
    time_dif = 9.0
  	@kDash = (365.0 * @Y) + (30.0 * @M) + @D - (33.5) + ((3.0 * (@M + 1.0)) / 5.0).floor + (@Y / 4.0).floor  - (time_dif / 24.0)
  	
    #Δt:地球自転の遅れ：2000年を65秒とし、毎年1秒遅れる
  	@deltaT = (57.0 + (0.8 * (time.year - 1990.0))) / 86400.0
  	
  	@G = ((time.hour * 3600.0) + (time.min * 60.0) + time.sec) / 86400.0
  	
  	#J2000からの経過ユリウス年
  	@T = (@kDash + @G + @deltaT) / 365.25
  	
  	return @T
  end
  
  #λ:黄経, β:黄緯により、黄道座標系を生成
  #太陽黄経(λs)を取得
  def GetSunEclipticLongitude(t)
      #λs:太陽黄経の算出
			@lambda_data =
			(280.46030 + (360.0076900 * t)) +
			(1.91460 - (0.0000500 * t)) *
								sin((DEG2RAD(357.53800 + (359.9910000 *   t)))) +
			0.02000 * sin((DEG2RAD(355.05000 + (719.9810000 *   t)))) +
			0.00480 * sin((DEG2RAD(234.95000 + (19.3410000 *    t)))) +
			0.00200 * sin((DEG2RAD(247.10000 + (329.6400000 *   t)))) +
			0.00180 * sin((DEG2RAD(297.80000 + (4452.6700000 *  t)))) +
			0.00180 * sin((DEG2RAD(251.30000 + (0.2000000 *     t)))) +
			0.00150 * sin((DEG2RAD(343.20000 + (450.3700000 *   t)))) +
			0.00130 * sin((DEG2RAD( 81.40000 + (225.1800000 *   t)))) +
			0.00080 * sin((DEG2RAD(132.50000 + (659.2900000 *   t)))) +
			0.00070 * sin((DEG2RAD(153.30000 + (90.3800000 *    t)))) +
			0.00070 * sin((DEG2RAD(206.80000 + (30.3500000 *    t)))) +
			0.00060 * sin((DEG2RAD( 29.80000 + (337.1800000 *   t)))) +
			0.00050 * sin((DEG2RAD(207.40000 + (1.5000000 *     t)))) +
			0.00050 * sin((DEG2RAD(291.20000 + (22.8100000 *    t)))) +
			0.00040 * sin((DEG2RAD(234.90000 + (315.5600000 *   t)))) +
			0.00040 * sin((DEG2RAD(157.30000 + (299.3000000 *   t)))) +
			0.00040 * sin((DEG2RAD( 21.10000 + (720.0200000 *   t)))) +
			0.00030 * sin((DEG2RAD(352.50000 + (1079.9700000 *  t)))) +
			0.00030 * sin((DEG2RAD(329.70000 + (44.4300000 *    t))))
			@lambda_data = ToAzimuthAngleRange(@lambda_data)
			return @lambda_data
  end
  
  def DEG2RAD(d)
    return (d * 0.017453292519943295)
  end
  
  def RAD2DEG(r)
    return (r * 57.295779513082323)
  end
  
  
  #太陽黄経(βs)を取得
  def GetSunEclipticLatitude
    return 0
  end
  
  #r:距離の算出
  def GetSunDistance(t)
		q = (0.007256 -                         (0.0000002 * t)) * 
		               sin((DEG2RAD(267.54000 + (359.9910000 * t)))) +
        0.000091 * sin((DEG2RAD(265.10000 + (719.9800000 * t)))) +
        0.000030 * sin((DEG2RAD( 90.00000))) +
        0.000013 * sin((DEG2RAD( 27.80000 + (4452.6700000 * t)))) +
        0.000007 * sin((DEG2RAD(254.80000 + (450.4000000 * t)))) +
        0.000007 * sin((DEG2RAD(156.00000 + (329.6000000 * t))))

			return 10**q
  end

  #ε:黄道傾角の算出
  def GetEcliptic(t)
    return ((23.439291) - (0.000130042 * t))
  end
  
  #赤道座標を算出
  def EquatorialCoordinate(t,ecliptic,epsilon)
    @equatorialcoordinate = Struct.new(:delta, :alpha)
    
    @sinLambda = sin(DEG2RAD(epsilon.lambda))
  	@cosLambda = cos(DEG2RAD(epsilon.lambda))
  	@sinBeta = sin(DEG2RAD(epsilon.beta))
  	@cosBeta = cos(DEG2RAD(epsilon.beta))
  	@sinEcliptic = sin(DEG2RAD(ecliptic))
  	@cosEcliptic = cos(DEG2RAD(ecliptic))
  
  	@U = (@cosBeta * @cosLambda)
  	@V = (-@sinBeta * @sinEcliptic) + (@cosBeta * @sinLambda * @cosEcliptic)
  	@W = (@sinBeta * @cosEcliptic) + (@cosBeta * @sinLambda * @sinEcliptic)
  	@U = @U
  	@V = @V
  	@W = @W
  
  	@tanAlpha = @V / @U
  
  	@aTanAlpha = RAD2DEG(atan(@tanAlpha))
    if 0.0 > @U
      @aTanAlpha += 180.0
    end
  	@aTanAlpha = ToAzimuthAngleRange(@aTanAlpha)
  
  	@tanDelta = @W / (sqrt((@U**2) + @V**2))
  	@aTanDelta = RAD2DEG(atan(@tanDelta))
  	
  	@equatorialcoordinate = @equatorialcoordinate.new(@aTanDelta, @aTanAlpha)
      
    return @equatorialcoordinate
  end
  
  def ToAzimuthAngleRange(aTanAlpha)
    @results = aTanAlpha.modulo(360.0)
    if @results < 0
      @results += 360
    end
    return @results
  end
  
  #太陽の視半径(Ｓ)を算出
  def GetSunVisualRadius(r)
    return (0.2669940 / r)
  end
  
  #Π:視差を算出
  def GetSunParallax(r)
    return (0.0024428 / r)
  end
  
  #時角(tk)を算出
  def GetHourAngle(k,delta,phi)
    cosTk = 
			((sin(DEG2RAD(k))) - 
			 (sin(DEG2RAD(delta)) * sin(DEG2RAD(phi)))) / 
			 (cos(DEG2RAD(delta)) * cos(DEG2RAD(phi)))
			return RAD2DEG(acos(cosTk))
  end
  
  
  #Θ:恒星時を算出
  def GetSiderealTime(t, d, lambda_data, utcOffsetTime)
    results =
				(100.4606 +
				(360.007700536 * t)) +
				(0.00000003879 * (t**2)) +
				(360.0 * d) - 
				(15 * utcOffsetTime) + lambda_data

			results = results.modulo(360.0)

			return results
  end
  
  #角度を -180.0°～ +180.0°の範囲に変換します。
  def ToHourAngleRange(angle)
    results = angle.modulo(360.0)

    if results > +180.0
        results -= 360.0
    else
      if results < -180.0
        results += 360.0
      end
    end

    return results
  end
  
  #時間変数を TimeSpan? 
  def ToTimeSpan(time)
    #日
    #work = time;
    #@day = work;

    #時
    #work = work.modulo(1.0)
    #work *= 24.0;
    #@hour = work;

    #分
    #work = work.modulo(1.0)
    #work *= 60.0;
    #@minutes = work;

    #秒
    #work = work.modulo(1.0)
    #work *= 60.0;
    #@seconds = work;

    #ミリ秒
    #work = work.modulo(1.0)
    #work *= 1000.0;
    #@milliseconds = work;

    #results = Time.local(0, 0, @day, @hour, @minutes, @seconds, @milliseconds)
    return time * 86400
  end
  
  #高度、方位角を算出
  def GetAzimuthAndAltitude(t, phi, delta, alpha)
    @sinDelta = sin(DEG2RAD(delta))
    @cosDelta = cos(DEG2RAD(delta))
    @sinAlpha = sin(DEG2RAD(alpha))
    @cosAlpha = cos(DEG2RAD(alpha))
    @sinPhi = sin(DEG2RAD(phi))
    @cosPhi = cos(DEG2RAD(phi))
    @sinT = sin(DEG2RAD(t))
    @cosT = cos(DEG2RAD(t))
    @azimuth = Float::NAN
    @altitude = Float::NAN

    @sinH = (@sinDelta * @sinPhi) + (@cosDelta * @cosPhi * @cosT)
    @altitude = RAD2DEG(asin(@sinH))
    
    #山田 洋　方式
		@correction = 0.0

		@b  = (2.8500000E-01)
		@a0 = (4.6640299E-09)
		@a1 = (3.0144174E-20)
		@a2 = (-1.4622375E-32)
		@a3 = (6.1448329E-01)
		@a4 = (7.0950227E-02)
		@a5 = (-4.3370511E-03)
		@a6 = (1.2705876E-04)
		@a7 = (-1.7021738E-06)
		@a8 = (9.0277974E-09)
		@Z = (90.0) - @altitude

		@atmosphericAverage =
		(
		(@a0 * (exp(1 * @b * @Z) -1)) +
		(@a1 * (exp(2 * @b * @Z) -1)) +
		(@a2 * (exp(3 * @b * @Z) -1)) +
		(@a3 * (@Z**1)) +
		(@a4 * (@Z**2)) +
		(@a5 * (@Z**3)) +
		(@a6 * (@Z**4)) +
		(@a7 * (@Z**5)) +
		(@a8 * (@Z**6))
		)

		if 0 == @atmosphericAverage
			@correction = 0
		else
			@correction = 1 / @atmosphericAverage
		end

		@atmosphericCorrection = @correction
		
    @quadrant = ((@sinDelta * @cosPhi) - (@cosDelta * @sinPhi * @cosT))
    @tanA = (-@cosDelta * @sinT) / @quadrant
    @azimuth = RAD2DEG(atan(@tanA))

    #象限の範囲指定
    if 0 < @quadrant
      @azimuth += 0.0
    else
      if 0 > @quadrant
          @azimuth += 180.0
      else
        if 0 < @sinT
          @azimuth = -90.0
        end
        if 0 > @sinT
            @azimuth += +90.0
        else
          @altitude = 90.0
          @azimuth = Float::NAN
        end
      end
      @azimuth = ToAzimuthAngleRange(@azimuth)
    end
    @AzimuthAndAltitude2 = Struct.new(:azimuth, :altitude)
    @azimuth_altitude2 = @AzimuthAndAltitude1.new()
  	@azimuth_altitude2.azimuth = @azimuth
  	@azimuth_altitude2.altitude = @altitude
  	return @azimuth_altitude2
  end
end

	#なし
	#市民薄明, 常用薄明(6°まで)。太陽高度-50分～-6度。まだ十分に明るさが残っていて、人工照明がなくても屋外で活動ができる明るさ。
	#航海薄明(6°から12°まで)。海面と空との境が見分けられる程度の明るさ。
	#天文薄明(12°から18°まで)。6等星までを肉眼で見分けられる暗さになる前の明るさ。
  #enum TWILIGHTTYPES:    [ :NONE, :REGULAR, :ASTRONOMY, :ASTRONOMY, :VOYAGE]
