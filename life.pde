// <Configuration>

// The width of each cell in pixels
final int CELL_SIZE = 20;

// The width of the canvas in pixels
int CANVAS_WIDTH = null;

// THe height of the canvas in pixels
int CANVAS_HEIGHT = null;

// THe background color
final color BACKGROUND = #FFFFFF;

// The color the filles cells are drawn with (will actually be a value between
// BACKGROUND and this color).
final color FOREGROUND = #EEEEEE;

// The frames per second to render at.
final int FPS = 10;

// The number of seconds to wait before killing everyone and starting again.
final int SECONDS_ALIVE = 200;

// If the density dips below this value, everyone will be killed and the game
// will be restarted.
final float MIN_DENSITY = 0.05;

// The density of the starting seed.
final float START_DENSITY = 0.5;

// </Configuration>

class Cell {
  boolean alive;
  float heat;
}

int wrap(int v, int max) {
  if (v < 0) {
    v = max + v;
    wrap(v, max);
  }

  return v % max;
}

class Grid {
  Cell[][] cells;
  int width;
  int height;

  Grid(int width, int height) {
    this.cells = new Cell[width][height];
    this.clear();

    this.width = width;
    this.height = height;
  }

  void clear() {
    for (int i = 0; i < this.width; ++i) {
      for (int j = 0; j < this.height; ++j) {
        this.cells[i][j] = new Cell();
      }
    }
  }

  void resize(int width, int height) {
    new_cells = new Cell[width][height];
    for (int i = 0; i < width; ++i) {
      for (int j = 0; j < height; ++j) {
        if (i < this.width && j < this.height) {
          new_cells[i][j] = this.cells[i][j];
        } else {
          new_cells[i][j] = new Cell();
        }
      }
    }

    this.cells = new_cells;
    this.width = width;
    this.height = height;
  }

  void randomize(float density) {
    this.clear();

    for (int i = 0; i < this.width * this.height * density; ++i) {
      Cell cur = cells[(int)random(this.width - 1)][(int)random(this.height - 1)];
      cur.alive = true;
    }
  }

  void draw() {
    for (int i = 0; i < this.width; ++i) {
      for (int j = 0; j < this.height; ++j) {
        if (this.cells[i][j].heat != 0.0) {
          fill(lerpColor(BACKGROUND, FOREGROUND, this.cells[i][j].heat));;
          rect(i * CELL_SIZE, j * CELL_SIZE, CELL_SIZE, CELL_SIZE);
        }
      }
    }
  }

  int _num_neighbors(int x, int y) {
    int result = 0;
    for (int i = -1; i <= 1; ++i) {
      for (int j = -1; j <= 1; ++j) {
        if (i == 0 && j == 0) {
          continue;
        }

        if (this.cells[wrap(x + i, this.width)][wrap(y + j, this.height)].alive) {
          ++result;
        }
      }
    }

    return result;
  }

  void step() {
    int neighbors[][] = new int[this.width][this.height];
    boolean alive[][] = new boolean[this.width][this.height];

    for (int i = 0; i < this.width; ++i) {
      for (int j = 0; j < this.height; ++j) {
        alive[i][j] = cells[i][j].alive;
        neighbors[i][j] = _num_neighbors(i, j);
      }
    }

    for (int i = 0; i < this.width; ++i) {
      for (int j = 0; j < this.height; ++j) {
        if (alive[i][j]) {
          this.cells[i][j].alive = (
            neighbors[i][j] == 2 || neighbors[i][j] == 3
          );
        } else {
          this.cells[i][j].alive = (neighbors[i][j] == 3);
        }

        if (this.cells[i][j].alive) {
          this.cells[i][j].heat = min(this.cells[i][j].heat + 0.3, 1.0);
        } else {
          this.cells[i][j].heat = max(this.cells[i][j].heat - 0.2, 0.0);
        }
      }
    }
  }

  void cool() {
    for (int i = 0; i < this.width; ++i) {
      for (int j = 0; j < this.height; ++j) {
        this.cells[i][j].heat = max(this.cells[i][j].heat - 0.2, 0.0);
      }
    }
  }

  void kill_all() {
    for (int i = 0; i < this.width; ++i) {
      for (int j = 0; j < this.height; ++j) {
        this.cells[i][j].alive = false;
      }
    }
  }

  float density() {
    int nalive = 0;
    for (int i = 0; i < this.width; ++i) {
      for (int j = 0; j < this.height; ++j) {
        if (this.cells[i][j].alive) {
          ++nalive;
        }
      }
    }

    return ((float)nalive) / (this.width * this.height);
  }

  boolean icy() {
    for (int i = 0; i < this.width; ++i) {
      for (int j = 0; j < this.height; ++j) {
        if (this.cells[i][j].heat != 0.0) {
          return false;
        }
      }
    }

    return true;
  }
}

Grid g;

final int STATE_NORMAL = 0;
final int STATE_DYING = 1;

int state = STATE_NORMAL;

int desired_width() {
  return CANVAS_WIDTH == null ? (int)window.innerWidth : CANVAS_WIDTH;
}

int desired_height() {
  return CANVAS_HEIGHT == null ? (int)window.innerHeight : CANVAS_HEIGHT;
}

void setup() {
  size(desired_width(), desired_height());
  frameRate(FPS);
  noStroke();

  g = new Grid((int)ceil(width / CELL_SIZE), (int)ceil(height / CELL_SIZE));
  g.randomize(START_DENSITY);
}

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
}
