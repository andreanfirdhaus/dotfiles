# Map matugen JSON (with -j hex) onto the dotfiles palette schema.
def d: .dark.color;
def b16($key): .base16[$key].dark.color;

{
  label: "Wallpaper",
  ui: {
    bg: (.colors.background | d),
    surface: (.colors.surface_container | d),
    overlay: (.colors.surface_container_high | d),
    line: (.colors.surface_container_highest | d),
    border: (.colors.outline_variant | d),
    dim: (.colors.outline | d),
    fg: (.colors.on_surface | d),
    bright: (.colors.on_background | d),
    accent: (.colors.primary | d),
    accentFg: (.colors.on_primary | d),
    hint: (.colors.tertiary | d),
    red: b16("base08"),
    orange: b16("base09"),
    yellow: b16("base0a"),
    green: b16("base0b"),
    cyan: b16("base0c"),
    blue: b16("base0d"),
    purple: b16("base0e")
  },
  syntax: {
    comment: (.colors.outline | d),
    string: b16("base0b"),
    number: b16("base09"),
    keyword: b16("base0e"),
    function: b16("base0d"),
    type: b16("base0a"),
    constant: b16("base09"),
    property: (.colors.on_surface | d),
    parameter: b16("base08"),
    operator: b16("base0c"),
    builtin: b16("base0a"),
    visual: (.colors.surface_container_high | d),
    search: (.colors.surface_container_highest | d)
  },
  ansi: {
    black: b16("base00"),
    red: b16("base08"),
    green: b16("base0b"),
    yellow: b16("base0a"),
    blue: b16("base0d"),
    magenta: b16("base0e"),
    cyan: b16("base0c"),
    white: b16("base05"),
    brightBlack: b16("base03"),
    brightRed: b16("base08"),
    brightGreen: b16("base0b"),
    brightYellow: b16("base0a"),
    brightBlue: b16("base0d"),
    brightMagenta: b16("base0e"),
    brightCyan: b16("base0c"),
    brightWhite: b16("base07")
  }
}
