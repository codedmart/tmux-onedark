#!/usr/bin/env bash
# setting the locale, some users have issues with different locales, this forces the correct one
export LC_ALL=en_US.UTF-8

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $current_dir/utils.sh

main()
{
  datafile=/tmp/.dracula-tmux-data

  # set configuration option variables
  show_fahrenheit=$(get_tmux_option "@dracula-show-fahrenheit" true)
  show_location=$(get_tmux_option "@dracula-show-location" true)
  fixed_location=$(get_tmux_option "@dracula-fixed-location")
  show_powerline=$(get_tmux_option "@dracula-show-powerline" false)
  show_flags=$(get_tmux_option "@dracula-show-flags" false)
  show_left_icon=$(get_tmux_option "@dracula-show-left-icon" smiley)
  show_left_icon_padding=$(get_tmux_option "@dracula-left-icon-padding" 1)
  show_military=$(get_tmux_option "@dracula-military-time" false)
  show_timezone=$(get_tmux_option "@dracula-show-timezone" true)
  show_left_sep=$(get_tmux_option "@dracula-show-left-sep" )
  show_right_sep=$(get_tmux_option "@dracula-show-right-sep" )
  show_border_contrast=$(get_tmux_option "@dracula-border-contrast" false)
  show_day_month=$(get_tmux_option "@dracula-day-month" false)
  show_refresh=$(get_tmux_option "@dracula-refresh-rate" 5)
  IFS=' ' read -r -a plugins <<< $(get_tmux_option "@dracula-plugins" "battery network weather")

  # Dracula Color Pallette
  black='#272822'
  white='#f8f8f8'
  gray='#808080'
  purple='#ae81ff'
  cyan='#66d9ef'
  green='#a6e22e'
  orange='#ef5939'
  red='#ff0000'
  pink='#f92672'
  yellow='#e6db74'

  # Handle left icon configuration
  case $show_left_icon in
    smiley)
      left_icon="☺";;
    session)
      left_icon="#S";;
    window)
      left_icon="#W";;
    *)
      left_icon=$show_left_icon;;
  esac

  # Handle left icon padding
  padding=""
  if [ "$show_left_icon_padding" -gt "0" ]; then
    padding="$(printf '%*s' $show_left_icon_padding)"
  fi
  left_icon="$left_icon$padding"

  # Handle powerline option
  if $show_powerline; then
    right_sep="$show_right_sep"
    left_sep="$show_left_sep"
  fi

  # start weather script in background
  if [[ "${plugins[@]}" =~ "weather" ]]; then
    $current_dir/sleep_weather.sh $show_fahrenheit $show_location $fixed_location &
  fi

  # Set timezone unless hidden by configuration
  case $show_timezone in
    false)
      timezone="";;
    true)
      timezone="#(date +%Z)";;
  esac

  case $show_flags in
    false)
      flags=""
      current_flags="";;
    true)
      flags="#{?window_flags,#[fg=${cyan}]#{window_flags},}"
      current_flags="#{?window_flags,#[fg=${cyan}]#{window_flags},}"
  esac

  # sets refresh interval to every 5 seconds
  tmux set-option -g status-interval $show_refresh

  # set the prefix + t time format
  if $show_military; then
    tmux set-option -g clock-mode-style 24
  else
    tmux set-option -g clock-mode-style 12
  fi

  # set length
  tmux set-option -g status-left-length 100
  tmux set-option -g status-right-length 100

  # pane border styling
  if $show_border_contrast; then
    tmux set-option -g pane-active-border-style "fg=${purple}"
  else
    tmux set-option -g pane-active-border-style "fg=${purple}"
  fi
  tmux set-option -g pane-border-style "fg=${gray}"

  # message styling
  tmux set-option -g message-style "bg=${black},fg=${white}"

  # status bar
  tmux set-option -g status-style "bg=${black},fg=${white}"

  # Status left
  if $show_powerline; then
    tmux set-option -g status-left "#[bg=${green},fg=${black}]#{?client_prefix,#[bg=${yellow}],} ${left_icon} #[fg=${green},bg=${black}]#{?client_prefix,#[fg=${yellow}],}${left_sep}"
    powerbg=${black}
  else
    tmux set-option -g status-left "#[bg=${green},fg=${black}]#{?client_prefix,#[bg=${yellow}],} ${left_icon}"
  fi

  # Status right
  tmux set-option -g status-right ""

  for plugin in "${plugins[@]}"; do

    if [ $plugin = "git" ]; then
      IFS=' ' read -r -a colors  <<< $(get_tmux_option "@dracula-git-colors" "green black")
        script="#($current_dir/git.sh)"     
    fi

    if [ $plugin = "battery" ]; then
      IFS=' ' read -r -a colors <<< $(get_tmux_option "@dracula-battery-colors" "pink black")
      script="#($current_dir/battery.sh)"
    fi

    if [ $plugin = "gpu-usage" ]; then
      IFS=' ' read -r -a colors <<< $(get_tmux_option "@dracula-gpu-usage-colors" "pink black")
      script="#($current_dir/gpu_usage.sh)"
    fi

    if [ $plugin = "cpu-usage" ]; then
      IFS=' ' read -r -a colors <<< $(get_tmux_option "@dracula-cpu-usage-colors" "orange black")
      script="#($current_dir/cpu_info.sh)"
    fi

    if [ $plugin = "ram-usage" ]; then
      IFS=' ' read -r -a colors <<< $(get_tmux_option "@dracula-ram-usage-colors" "cyan black")
      script="#($current_dir/ram_info.sh)"
    fi

    if [ $plugin = "network" ]; then
      IFS=' ' read -r -a colors <<< $(get_tmux_option "@dracula-network-colors" "cyan black")
      script="#($current_dir/network.sh)"
    fi

    if [ $plugin = "network-bandwidth" ]; then
      IFS=' ' read -r -a colors <<< $(get_tmux_option "@dracula-network-bandwidth-colors" "cyan black")
      tmux set-option -g status-right-length 250
      script="#($current_dir/network_bandwidth.sh)"
    fi

    if [ $plugin = "network-ping" ]; then
      IFS=' ' read -r -a colors <<<$(get_tmux_option "@dracula-network-ping-colors" "cyan black")
      script="#($current_dir/network_ping.sh)"
    fi

    if [ $plugin = "weather" ]; then
      # wait unit $datafile exists just to avoid errors
      # this should almost never need to wait unless something unexpected occurs
      while [ ! -f $datafile ]; do
        sleep 0.01
      done

      IFS=' ' read -r -a colors <<< $(get_tmux_option "@dracula-weather-colors" "orange black")
      script="#(cat $datafile)"
    fi

    if [ $plugin = "time" ]; then
      IFS=' ' read -r -a colors <<< $(get_tmux_option "@dracula-time-colors" "purple black")
      if $show_day_month && $show_military ; then # military time and dd/mm
        script="%a %d/%m %R ${timezone} "
      elif $show_military; then # only military time
        script="%a %m/%d %R ${timezone} "
      elif $show_day_month; then # only dd/mm
        script="%a %d/%m %I:%M %p ${timezone} "
      else
        script="%a %m/%d %I:%M %p ${timezone} "
      fi
    fi

    if $show_powerline; then
      tmux set-option -ga status-right "#[fg=${!colors[0]},bg=${powerbg},nobold,nounderscore,noitalics]${right_sep}#[fg=${!colors[1]},bg=${!colors[0]}] $script "
      powerbg=${!colors[0]}
    else
      tmux set-option -ga status-right "#[fg=${!colors[1]},bg=${!colors[0]}] $script "
    fi
  done

  # Window option
  if $show_powerline; then
    tmux set-window-option -g window-status-current-format "#[fg=${black},bg=${pink}]${left_sep}#[fg=${black},bg=${pink}] #I #W${current_flags} #[fg=${pink},bg=${gray}]${left_sep}"
  else
    tmux set-window-option -g window-status-current-format "#[fg=${black},bg=${pink}] #I #W${current_flags} "
  fi

  tmux set-window-option -g window-status-format "#[fg=${white}]#[bg=${gray}] #I #W${flags}"
  tmux set-window-option -g window-status-activity-style "bold"
  tmux set-window-option -g window-status-bell-style "bold"
}

# run main function
main
