///////////////////
// Configuration //
///////////////////

// The width of each cell in pixels
final int CELL_SIZE = 10;

// The width of the canvas in pixels. 0 uses whole screen.
int CANVAS_WIDTH = 0;

// THe height of the canvas in pixels. 0 uses whole screen.
int CANVAS_HEIGHT = 0;

// THe background color
final color BACKGROUND = #FFFFFF;

// The color the filles cells are drawn with (will actually be a value between
// BACKGROUND and this color).
final color FOREGROUND = #EEEEEE;

// The color the cell gets closer to when it is closer to the cursor
final color FOREGROUND_BRIGHT = #60B3B3;

// This will be decremented by a certain amount each frame, once it reaches
// zero the cell will experience a step in time.
final float MAX_TIME_TO_STEP = 40.0;

// The frames per second to render at.
final int FPS = 10;

// The number of seconds to wait before killing everyone and starting again.
final int SECONDS_ALIVE = 200;

// If the density dips below this value, everyone will be killed and the game
// will be restarted.
final float MIN_DENSITY = 0.1;

// The density of the starting seed.
final float START_DENSITY = 0.5;

//////////////////
// Global State //
//////////////////

// The github image we'll put in the center
PImage github_img;

// The game grid
Grid g;

// The state of the game
final int STATE_NORMAL = 0;
final int STATE_DYING = 1;
int state = STATE_NORMAL;

/////////////
// Program //
/////////////

class Cell {
  // Whether the cell is alive or dead
  boolean alive;

  // The "heat" of the cell which is a value in [0.0, 1.0] that tells how
  // dark the cell should be rendered.
  float heat;

  // The time to step. A counter to help keep track of this cell's sense of
  // time.
  int tts;
}

// Wraps a value around a given max. Basically modulus but handles negative
// numbers.
int wrap(int v, int max) {
  if (v < 0) {
    int x = max - (-v) % 10;
    if (x == 10) {
      return 0;
    } else {
      return x;
    }
  } else {
    return v % max;
  }
}

class Grid {
  Cell cells_[][];
  int width_;
  int height_;

  Grid(int zwidth, int zheight) {
    this.cells_ = new Cell[zwidth][zheight];
    this.clear();

    this.width_ = zwidth;
    this.height_ = zheight;
  }

  // Completely wipes the board and gives it all new cells.
  void clear() {
    for (int i = 0; i < this.width_; ++i) {
      for (int j = 0; j < this.height_; ++j) {
        this.cells_[i][j] = new Cell();
      }
    }
  }

  // Resizes the board, preserving cells where possible
  void resize(int width, int height) {
    Cell new_cells[][] = new Cell[width][height];
    for (int i = 0; i < width; ++i) {
      for (int j = 0; j < height; ++j) {
        if (i < this.width_ && j < this.height_) {
          new_cells[i][j] = this.cells_[i][j];
        } else {
          new_cells[i][j] = new Cell();
        }
      }
    }

    this.cells_ = new_cells;
    this.width_ = width;
    this.height_ = height;
  }

  // Randomly populate the game board. Density is imprecise because a cell
  // can be brought to life twice.
  void randomize(float density) {
    this.clear();

    for (int i = 0; i < this.width_ * this.height_ * density; ++i) {
      Cell cur = this.cells_[(int)random(this.width_ - 1)][(int)random(this.height_ - 1)];
      cur.alive = true;
    }
  }

  void draw() {
    for (int i = 0; i < this.width_; ++i) {
      for (int j = 0; j < this.height_; ++j) {
        if (this.cells_[i][j].heat != 0.0) {
          // This takes care of the distance to mouse coloring
          color adjusted_foreground = lerpColor(
            FOREGROUND, FOREGROUND_BRIGHT, _tts_mod(i, j) / 100.0);

          fill(lerpColor(BACKGROUND, adjusted_foreground,
            this.cells_[i][j].heat));;
          rect(i * CELL_SIZE, j * CELL_SIZE, CELL_SIZE, CELL_SIZE);
        }
      }
    }
  }

  // Determine how much should be subtracted from a given cell's tts
  int _tts_mod(int x, int y) {
    // Figure out the size of the screen
    float diagonal = dist(0, 0, desired_width(), desired_height());

    // Figure out the distance between the current cell and the mouse
    float distance_to_mouse = dist(
      mouseX, mouseY,
      x * CELL_SIZE + CELL_SIZE / 2, y * CELL_SIZE + CELL_SIZE / 2
    ) / CELL_SIZE;

    // Formula found through tweaking.
    float mod = 100.0 * (1468.0 / diagonal) - pow(distance_to_mouse, 1.2);

    return max(mod, 0.0);
  }

  int _num_neighbors(int x, int y) {
    int result = 0;
    // Look all around this cell (8 cells in total to look at)
    for (int i = -1; i <= 1; ++i) {
      for (int j = -1; j <= 1; ++j) {
        // Skip our cell
        if (i == 0 && j == 0) {
          continue;
        }

        if (this.cells_[wrap(x + i, this.width_)][wrap(y + j, this.height_)].alive) {
          ++result;
        }
      }
    }

    return result;
  }

  void step() {
    // Determine the number of neighbors for each cell. Also keep track of
    // which cells are alive right now because we're about to modify the array
    // of cells in place.
    int neighbors[][] = new int[this.width_][this.height_];
    boolean alive[][] = new boolean[this.width_][this.height_];
    for (int i = 0; i < this.width_; ++i) {
      for (int j = 0; j < this.height_; ++j) {
        alive[i][j] = this.cells_[i][j].alive;
        neighbors[i][j] = _num_neighbors(i, j);
      }
    }

    for (int i = 0; i < this.width_; ++i) {
      for (int j = 0; j < this.height_; ++j) {
        // Determine if this cell gets to step through time right now
        this.cells_[i][j].tts -= _tts_mod(i, j);
        if (this.cells_[i][j].tts <= 0.0) {
          // Determine if the cell should live or die
          if (alive[i][j]) {
            this.cells_[i][j].alive = (
              neighbors[i][j] == 2 || neighbors[i][j] == 3
            );
          } else {
            this.cells_[i][j].alive = (neighbors[i][j] == 3);
          }

          // Heat or cool the cell to get the nice fading effect
          if (this.cells_[i][j].alive) {
            this.cells_[i][j].heat = min(this.cells_[i][j].heat + 0.3, 1.0);
          } else {
            this.cells_[i][j].heat = max(this.cells_[i][j].heat - 0.2, 0.0);
          }

          // Reset the cell's time to step
          this.cells_[i][j].tts = MAX_TIME_TO_STEP;
        }
      }
    }
  }

  // Lower the head of every cell
  void cool() {
    for (int i = 0; i < this.width_; ++i) {
      for (int j = 0; j < this.height_; ++j) {
        this.cells_[i][j].heat = max(this.cells_[i][j].heat - 0.1, 0.0);
      }
    }
  }

  void kill_all() {
    for (int i = 0; i < this.width_; ++i) {
      for (int j = 0; j < this.height_; ++j) {
        this.cells_[i][j].alive = false;
      }
    }
  }

  float density() {
    int nalive = 0;
    for (int i = 0; i < this.width_; ++i) {
      for (int j = 0; j < this.height_; ++j) {
        if (this.cells_[i][j].alive) {
          ++nalive;
        }
      }
    }

    return ((float)nalive) / (this.width_ * this.height_);
  }

  // Returns true if the entire board's heat is 0
  boolean icy() {
    for (int i = 0; i < this.width_; ++i) {
      for (int j = 0; j < this.height_; ++j) {
        if (this.cells_[i][j].heat != 0.0) {
          return false;
        }
      }
    }

    return true;
  }
}

int desired_width() {
  return CANVAS_WIDTH == 0 ? (int)window.innerWidth : CANVAS_WIDTH;
}

int desired_height() {
  return CANVAS_HEIGHT == 0 ? (int)window.innerHeight : CANVAS_HEIGHT;
}

void setup() {
  // Resize our canvas to match our desired dimensions
  size(desired_width(), desired_height());

  // This will determine how quickly the draw() function below is called
  frameRate(FPS);

  // We never want to draw outlines on our shapes
  noStroke();

  // Load the image we will place in the center of the canvas
  github_img = loadImage("github.png");

  // Create our actual game grid (which contains most of the needed game
  // logic).
  g = new Grid((int)ceil(width / CELL_SIZE), (int)ceil(height / CELL_SIZE));

  // Initialize the grid to our desired starting density
  g.randomize(START_DENSITY);
}

/// @brief Fills the canvas with our background color.
void clear_screen() {
  fill(BACKGROUND);
  rect(0, 0, width, height);
}

int counter = 0;
void draw() {
  if (height != desired_height() || width != desired_width()) {
    size(desired_width(), desired_height());
    g.resize((int)ceil(width / CELL_SIZE), (int)ceil(height / CELL_SIZE));
  }

  clear_screen();
  g.draw();

  if (state == STATE_NORMAL) {
    g.step();
    ++counter;

    if (g.density() < MIN_DENSITY || counter > FPS * SECONDS_ALIVE) {
      state = STATE_DYING;
      counter = 0;
      g.kill_all();
    }
  } else if (state == STATE_DYING) {
    g.cool();
    if (g.icy()) {
      state = STATE_NORMAL;
      g.randomize(START_DENSITY);
    }
  }

  int canvas_center_x = desired_width() / 2;
  int canvas_center_y = desired_height() / 2;

  float img_alpha = dist(mouseX, mouseY, canvas_center_x, canvas_center_y);
  img_alpha = 500.0 / (img_alpha * img_alpha);
  img_alpha = min(img_alpha, 1.0);

  tint(255, 64 * img_alpha);
  image(
    github_img,
    canvas_center_x - github_img.width / 2,
    canvas_center_y - github_img.height / 2
  );

  if (is_mouse_over_image()) {
    document.getElementById("game-canvas").style.cursor = "pointer";
  } else {
    document.getElementById("game-canvas").style.cursor = "auto";
  }
}

void mouseReleased() {
  if (is_mouse_over_image()) {
    window.location = "https://github.com/brownhead/processing-life";
  }
}

bool is_mouse_over_image() {
  int canvas_center_x = desired_width() / 2;
  int canvas_center_y = desired_height() / 2;

  int img_left = canvas_center_x - github_img.width / 2;
  int img_top = canvas_center_y - github_img.height / 2;
  int img_right = canvas_center_x + github_img.width / 2;
  int img_bottom = canvas_center_y + github_img.height / 2;

  return mouseX > img_left && mouseX < img_right &&
    mouseY > img_top && mouseY < img_bottom;
}
