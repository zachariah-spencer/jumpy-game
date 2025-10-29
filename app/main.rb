class Game
  attr_gtk

  def initialize args
    self.args = args
    state.walls << wall
  end

  def wall
    wall_tiles = []
    gaps_num = Numeric.rand(1..3)

    random_gaps = []
    gaps_num.times { random_gaps << Numeric.rand(0..19) }

    20.times do |i|
      next if random_gaps.include? i
      
      wall_tiles << {
        x: 64 * i,
        y: 40,
        w: 64,
        h: 64,
        path: "sprites/chroma-noir/overworld.png",
        tile_x: 8 * 0,
        tile_y: 8 * 24,
        tile_w: 8,
        tile_h: 8,
      }
    end

    wall_tiles
  end

  def tick
    calc
    render
  end

  def calc
    state.walls.flatten.each { |wall| wall.y += state.obstacle_speed }

    # inputs
    state.player.dx += Numeric.rand(7..10) if inputs.keyboard.key_down.d
    state.player.dx -= Numeric.rand(7..10) if inputs.keyboard.key_down.a
    
    player_distance_to_center = (Geometry.distance [0, state.player.y], [0, Grid.h / 2 - 16]) * 0.08
    player_distance_to_center *= -1 if state.player.y >= Grid.h / 2 - 16
    state.player.dy = player_distance_to_center

    state.player.x += state.player.dx
    state.player.y += state.player.dy

    state.player.dx *= 0.95
    state.player.dy *= 0.95

    if state.player.x <= 0
      state.player.x = 0
      state.player.dx = 0
    end

    # horizontal edge of screen collisions
    if state.player.x >= Grid.w - state.player.w
      state.player.x = Grid.w - state.player.w
      state.player.dx = 0
    end

    state.walls.flatten.each do |wall|
      if wall.intersect_rect? state.player
        state.player.y = wall.y + wall.h
        state.player.dy = 0
      end
    end

    # loss con
    if state.player.y > Grid.h
      GTK.reset_next_tick
    end

    # player circular floating
    omega = state.player.floating_rpm * 2 * Math::PI / 60.0
    state.player.floating_theta = (state.player.floating_theta + omega * (1.0/60.0)) % (2*Math::PI)
    
    float_x = state.player.floating_radius * Math.cos(state.player.floating_theta)
    float_y = state.player.floating_radius * Math.sin(state.player.floating_theta)
    state.player.render_x = (state.player.x + float_x).clamp(0, Grid.w - state.player.w)
    state.player.render_y = state.player.y + float_y
  end

  def render
    outputs.background_color = [ 13, 13, 13 ]
    outputs.sprites << state.player.merge(
      x: state.player.render_x,
      y: state.player.render_y
    )

    outputs.sprites << state.walls
  end

end

def defaults args
  args.state.player ||= {
    x: Grid.w / 2 - 16,
    y: Grid.h / 2 - 16,
    dx: 0,
    dy: 0,
    w: 32,
    h: 32,
    path: "sprites/chroma-noir/hero.png",
    tile_x: 8 * 0,
    tile_y: 8 * 1,
    tile_w: 8,
    tile_h: 8,
    floating_radius: 20,
    floating_rpm: 8,
    floating_theta: 0,
    render_x: 0,
    render_y: 0,
  }

  args.state.obstacle_speed ||= 2

  args.state.walls ||= []
end

def tick args
  defaults args
  $game ||= Game.new args
  $game.tick
end