class Game
  attr_gtk

  def initialize args
    self.args = args
    @wall_spawned_tick = Kernel.tick_count
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
        y: -64,
        prev_y: -64,
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
    if @wall_spawned_tick && @wall_spawned_tick.elapsed_time >= state.obstacle_delay
      state.walls << wall
      @wall_spawned_tick = Kernel.tick_count
      state.obstacle_speed += 0.25
      state.obstacle_delay -= 0.1.seconds
      state.obstacle_speed = state.obstacle_speed.clamp(0, 10)
      state.obstacle_delay = state.obstacle_delay.clamp(0.5.seconds, 3.0.seconds)
      puts state.obstacle_delay
    end
    calc
    render
  end

  def calc
    state.walls.flatten.each do |wall|
      wall.prev_y = wall.y
      wall.y += state.obstacle_speed
    end

    # inputs
    state.player.dx += Numeric.rand(7..10) if inputs.keyboard.key_down.d
    state.player.dx -= Numeric.rand(7..10) if inputs.keyboard.key_down.a
    
    player_distance_to_center = (Geometry.distance [0, state.player.y], [0, Grid.h / 2 - 16]) * 0.08
    player_distance_to_center *= -1 if state.player.y >= Grid.h / 2 - 16
    state.player.dy = player_distance_to_center

    state.player.prev_x = state.player.x
    state.player.prev_y = state.player.y

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

    colliding_with_wall = false
    state.walls.flatten.each do |wall|
      next unless wall.intersect_rect? state.player

      colliding_with_wall = true

      wall_left = wall.x
      wall_right = wall_left + wall.w
      wall_bottom = wall.y
      wall_top = wall_bottom + wall.h

      player_left = state.player.x
      player_right = player_left + state.player.w
      player_bottom = state.player.y
      player_top = player_bottom + state.player.h

      overlap_left = player_right - wall_left
      overlap_right = wall_right - player_left
      overlap_bottom = player_top - wall_bottom
      overlap_top = wall_top - player_bottom

      next if overlap_left <= 0 || overlap_right <= 0 || overlap_bottom <= 0 || overlap_top <= 0

      min_overlap_x = [overlap_left, overlap_right].min
      min_overlap_y = [overlap_bottom, overlap_top].min

      if min_overlap_y <= min_overlap_x
        if overlap_bottom < overlap_top
          state.player.y = wall_bottom - state.player.h
          state.player.dy = 0 if state.player.dy > 0
        else
          state.player.y = wall_top
          state.player.dy = 0 if state.player.dy < 0
        end
      else
        if overlap_left < overlap_right
          state.player.x = wall_left - state.player.w
          state.player.dx = 0 if state.player.dx > 0
        else
          state.player.x = wall_right
          state.player.dx = 0 if state.player.dx < 0
        end
      end
    end

    # loss con
    if state.player.y > Grid.h
      GTK.reset_next_tick
    end

    state.player.float_resume_progress ||= 1.0
    if colliding_with_wall
      state.player.float_resume_progress = (state.player.float_resume_progress - 0.12).clamp(0.0, 1.0)
    else
      state.player.float_resume_progress = (state.player.float_resume_progress + 0.08).clamp(0.0, 1.0)
    end

    # player circular floating
    omega = state.player.floating_rpm * 2 * Math::PI / 60.0
    state.player.floating_theta = (state.player.floating_theta + omega * (1.0/60.0)) % (2*Math::PI)
    
    float_x = state.player.floating_radius * Math.cos(state.player.floating_theta)
    float_y = state.player.floating_radius * Math.sin(state.player.floating_theta)
    resume_progress = state.player.float_resume_progress
    offset_x = float_x * resume_progress
    offset_y = float_y * resume_progress

    proposed_x = state.player.x + offset_x
    proposed_y = state.player.y + offset_y
    player_left = state.player.x
    player_right = state.player.x + state.player.w
    player_w = state.player.w
    player_h = state.player.h

    render_x = proposed_x.clamp(0, Grid.w - player_w)
    render_y = proposed_y

    if resume_progress.positive?
      state.walls.flatten.each do |wall|
        render_left = render_x
        render_right = render_left + player_w
        render_bottom = render_y
        render_top = render_bottom + player_h

        wall_left = wall.x
        wall_right = wall_left + wall.w
        wall_bottom = wall.y
        wall_top = wall_bottom + wall.h

        overlaps_vertically = render_bottom < wall_top && render_top > wall_bottom
        overlaps_horizontally = render_left < wall_right && render_right > wall_left
        next unless overlaps_vertically && overlaps_horizontally

        if player_right <= wall_left && render_right > wall_left
          render_x = wall_left - player_w
        elsif player_left >= wall_right && render_left < wall_right
          render_x = wall_right
        end

        render_x = render_x.clamp(0, Grid.w - player_w)
      end
    end

    state.player.render_x = render_x
    state.player.render_y = render_y
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
    float_resume_progress: 1.0,
    prev_x: Grid.w / 2 - 16,
    prev_y: Grid.h / 2 - 16,
  }

  args.state.obstacle_speed ||= 2
  args.state.obstacle_delay ||= 3.0.seconds

  args.state.walls ||= []
end

def tick args
  defaults args
  $game ||= Game.new args
  $game.tick
end
