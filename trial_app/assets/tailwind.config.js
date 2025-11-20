module.exports = {
  content: [
  "./js/**/*.js",
  "../lib/**/*.*exs",
  "../lib/**/*.*ex",
  "../lib/**/*.heex",
  "../lib/**/*.html.heex",
  "../lib/**/*.html.eex",
  "../priv/**/*.html"
],

  theme: {
    extend: {},
  },
  plugins: [
    require("daisyui")
  ],
}
