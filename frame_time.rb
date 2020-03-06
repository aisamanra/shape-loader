# typed: true

class FrameTime
  sig {params(blk: T.proc.returns(Time)).void}
  def initialize(&blk)
    @t_blk = blk
    @last_time = @t_blk.call
  end

  sig {returns(Float)}
  def dt
    current_time = @t_blk.call
    delta_time = current_time - @last_time
    @last_time = current_time
    return delta_time
  end
end
