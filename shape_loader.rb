# typed: true

require 'gosu'
require 'vector2d'
require 'sorbet-runtime'

require_relative 'frame_time'

include Gosu

class Object
  extend T::Sig
end

module ShapeLoader

  extend T::Sig

  sig {params(a: Vector2d, b: Vector2d).returns(Float)}
  def self.manhattan_distance(a, b)
    (a.x - b.x).abs + (a.y - b.y).abs
  end

  LEFT  = Vector2d.new(-1.0,  0.0)
  RIGHT = Vector2d.new( 1.0,  0.0)
  UP    = Vector2d.new( 0.0, -1.0)
  DOWN  = Vector2d.new( 0.0,  1.0)
  ZERO_VECTOR = Vector2d.new(0.0, 0.0)

  class Bounds < T::Struct
    prop :width, Integer
    prop :height, Integer
  end

  sig {params(n: T.any(Float, Integer)).returns(Integer)}
  def self.sign(n)
    if n > 0
      1
    elsif n < 0
      -1
    else
      0
    end
  end

  class Shape < T::Struct
    prop :pos, Vector2d
    prop :type, Symbol
  end

  class Truck < T::Struct
    prop :pos, Vector2d
    prop :vel, Vector2d
    prop :shapes_needed, T::Array[Symbol]
    prop :shapes_loaded, T::Array[Symbol]

    sig {params(dt: T.any(Float, Integer)).void}
    def step(dt)
      self.pos += (vel * dt)
    end
    def draw(world)

    end
  end

  class Loader < T::Struct
    prop :pos, Vector2d
    prop :vel, Vector2d
    prop :bucket_offset, Vector2d
    prop :nearby_shape, T.nilable(Shape)
    prop :nearby_needed_shape, T.nilable(Vector2d)
    prop :shape, T.nilable(Symbol)

    attr_accessor :shape

    sig {params(dt: T.any(Float, Integer), world: World).void}
    def step(dt, world)
      self.pos += (vel * dt)
      if self.pos.x < 0.0
        self.pos = Vector2d.new(0.0, self.pos.y)
      end

      if self.pos.y < 0.0
        self.pos = Vector2d.new(self.pos.x, 0.0)
      end

      if self.pos.x > 14.0
        self.pos = Vector2d.new(14.0, self.pos.y)
      end

      if self.pos.y > 13.0
        self.pos = Vector2d.new(self.pos.x, 13.0)
      end

      shp = nearby_shape
      needed = nearby_needed_shape
      if !shp.nil?
        desired_bucket_offset = shp.pos - Vector2d.new(-0.32, 0.32) - self.pos
      elsif !needed.nil?
        desired_bucket_offset = needed - Vector2d.new(-0.32, 0.32) - self.pos
      else
        desired_bucket_offset = ZERO_VECTOR
      end

      offset_error = desired_bucket_offset - bucket_offset
      bucket_speed = 5.0

      if offset_error != ZERO_VECTOR
        bucket_vel = offset_error.normalize * (bucket_speed * dt)
        if bucket_offset.distance(desired_bucket_offset) < bucket_vel.length
          self.bucket_offset = desired_bucket_offset
        else
          self.bucket_offset += bucket_vel
        end
      end

      offset_error = desired_bucket_offset - bucket_offset
      if offset_error == ZERO_VECTOR
        nearby = nearby_shape
        if !nearby.nil?
          self.shape = nearby.type
          world.shapes.delete(T.must(nearby_shape))
          nearby_shape = nil
        end
        if !nearby_needed_shape.nil?
          world.truck.shapes_loaded << T.must(self.shape)
          self.shape = nil
          world.truck.shapes_needed.shift

          if world.truck.shapes_needed.empty?
            world.truck.vel = Vector2d.new(-1.0, 0.0)
          end
        end
      end
      if world.truck.shapes_needed.empty?
        world.truck.vel = Vector2d.new(-1.0, 0.0)
        self.pos = world.truck.pos + (LEFT * 1.5) + (UP * 0.7)
      end
    end
  end

  SHAPES = [:triangle, :circle, :square, :diamond]

  SHAPES_NEEDED = {
    triangle: :triangle_needed,
    circle: :circle_needed,
    square: :square_needed,
    diamond: :diamond_needed,
  }



  class World < T::Struct
    prop :loader, Loader
    prop :truck, Truck
    prop :shapes, T::Array[Shape]
    prop :bounds, Bounds

    def self.create(bounds)
      positions = []
      [1, 3, 5, 7, 9, 11, 13].each do |x|
        [1, 3, 5, 7, 9, 11].each do |y|
          positions << Vector2d.new(x.to_f, y.to_f)
        end
      end
      positions.shuffle!

      shapes = (0..3).flat_map do |i|
        SHAPES.map do |s|
          Shape.new(pos: positions.shift, type: s)
        end
      end.to_a

      shapes_needed = [
        SHAPES_NEEDED[SHAPES.sample],
        SHAPES_NEEDED[SHAPES.sample],
        SHAPES_NEEDED[SHAPES.sample],
        SHAPES_NEEDED[SHAPES.sample]
      ]
      # shapes = circles + [ Shape.new(Vector2d.new(1.0, 3.0), :circle),
      #            Shape.new(Vector2d.new(3.0, 1.0), :circle),
      #            Shape.new(Vector2d.new(3.0, 3.0), :circle), ]
      World.new(
        loader: Loader.new(pos: Vector2d.new(10.0, 10.0),
                           vel: ZERO_VECTOR,
                           bucket_offset: ZERO_VECTOR,
                           nearby_shape: nil,
                           nearby_needed_shape: nil,
                           shape: nil),
        truck: Truck.new(pos: Vector2d.new(6.0, 13.0),
                         vel: ZERO_VECTOR,
                         shapes_needed: shapes_needed,
                         shapes_loaded: []),
        shapes: shapes,
        bounds: bounds)
    end

    def try_to_pickup_shape
      if loader.shape.nil?
        # shapes.detect
        false
      end
    end

    def update(vel, desired_bucket_offset)
      loader.vel = vel
      loader.nearby_shape = nil
      shapes.each_with_index do |shape, i|
        if loader.shape.nil? && ShapeLoader.manhattan_distance(shape.pos + (RIGHT*0.6), loader.pos) <= 0.6 &&
           truck.shapes_needed.first == SHAPES_NEEDED[shape.type]
          loader.nearby_shape = shape
          break
        end
      end

      if !loader.shape.nil? && ShapeLoader.manhattan_distance(truck.pos + (RIGHT*1.7) + (truck.shapes_needed.length * LEFT), loader.pos) <= 0.5
        loader.nearby_needed_shape = truck.pos + RIGHT + (truck.shapes_needed.length * LEFT)
      # truck.shapes_loaded << loader.shape
      # loader.shape = nil
      # truck.shapes_needed.shift

      # if truck.shapes_needed.empty?
      #   truck.vel = Vector2d.new(-1.0, 0.0)
      # end
      else
        loader.nearby_needed_shape = nil
      end
    end

    def step(dt)
      loader.step(dt, self)
      truck.step(dt)
    end
  end


  DIRECTIONS = { Gosu::KbLeft  => LEFT,
                 Gosu::KbRight => RIGHT,
                 Gosu::KbUp    => UP,
                 Gosu::KbDown  => DOWN }


  class Game < Gosu::Window
    attr_reader :images
    def initialize()
      super(480, 480, false)
      @frame_time = FrameTime.new do
        Time.now
      end

      T.unsafe(self).caption = "Shape Loader!"
      @images = { loader: Image.new(self, "./gfx/loader.png", false),
                  loader_arm: Image.new(self, "./gfx/loader_arm.png", false),
                  loader_scoop: Image.new(self, "./gfx/loader_scoop.png", false),
                  floor: Image.new(self, "./gfx/floor.png", false),
                  circle: Image.new(self, "./gfx/circle.png", false),
                  square: Image.new(self, "./gfx/square.png", false),
                  triangle: Image.new(self, "./gfx/triangle.png", false),
                  diamond: Image.new(self, "./gfx/diamond.png", false),
                  circle_needed: Image.new(self, "./gfx/circle_needed.png", false),
                  square_needed: Image.new(self, "./gfx/square_needed.png", false),
                  triangle_needed: Image.new(self, "./gfx/triangle_needed.png", false),
                  diamond_needed: Image.new(self, "./gfx/diamond_needed.png", false),
                  truck: Image.new(self, "./gfx/truck.png", false), }
      @our_id = nil
      restart
    end

    def restart
      @world = World.create(Bounds.new(width: 15, height: 15))
      @desired_bucket_offset = Vector2d.new(0.0, 0.0)

      @last_player_vel = ZERO_VECTOR
    end

    def needs_cursor?
      return true
    end

    def update
      commanded_directions = DIRECTIONS.select{ |key, value| self.button_down? key }.values
      player_vel = commanded_directions.inject(ZERO_VECTOR) { |sum, x| sum + x }
      @world.update(player_vel * 2.0, @desired_bucket_offset)
      @world.step(@frame_time.dt)

      # todo ignore sending events with the same velocity
      # player_vel = commanded_directions.inject(ZERO_VECTOR) { |sum, x| sum + x }
      # if player_vel != @last_player_vel
      #   @connection.send_event(Marshal.dump(player_vel * 5.0))
      # end
      # @last_player_vel = player_vel
      if @world.truck.pos.x < -2.0
        restart
      end
    end

    def draw_bucket(loader)
      bucket_offset = Vector2d.new(-0.32, 0.32) + loader.bucket_offset

      if not loader.shape.nil?
        pos = bucket_offset + loader.pos
        images[loader.shape].draw(pos.x * 32, pos.y * 32, 3)
      end

      pos = loader.bucket_offset + loader.pos
      images[:loader_arm].draw(pos.x * 32, loader.pos.y * 32, 3)
      images[:loader_scoop].draw(pos.x * 32, pos.y * 32, 3)
    end

    def draw_shape(shape)
      images[shape.type].draw(shape.pos.x * 32, shape.pos.y * 32, 1)
    end


    def draw
      images[:floor].draw(0.0, 0.0, 0)

      pos = @world.loader.pos
      images[:loader].draw(pos.x * 32, pos.y * 32, 3)

      pos = @world.truck.pos
      tpos = pos + (LEFT * 4)
      images[:truck].draw(tpos.x * 32, tpos.y * 32, 2)
      truck_shapes = @world.truck.shapes_loaded + @world.truck.shapes_needed
      truck_shapes.each_with_index do |shape_needed, i|
        spos = pos + (LEFT * (3-i))
        images[shape_needed].draw(spos.x * 32, spos.y * 32, 1)
      end

      @world.shapes.each do |shape|
        draw_shape(shape)
      end

      draw_bucket(@world.loader)


      #   @world.players.values.each do |p|
      #     images[:loader].draw((p.pos.x * 32).round, (p.pos.y * 32).round, 1)
      #   end
    end

    def quit
      T.unsafe(self).close
    end

    sig {params(id: T.untyped).void}
    def button_down(id)
      if id == Gosu::KbSpace then
        # if @desired_bucket_offset != Vector2d.new(-0.3, -0.3)
        #   @desired_bucket_offset = Vector2d.new(-0.3, -0.3)
        # else
        #   @desired_bucket_offset = Vector2d.new(0.0, 0.0)
        # end


      end
      if id == Gosu::KbEscape then
        quit
      end
    end
  end

  g = Game.new()
  T.unsafe(g).show

end
