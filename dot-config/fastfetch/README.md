# Neofetch Config 

───────────────────────────────────────────────  
 °˖* ૮( • ᴗ ｡)っ🍸 shheersh - Dionysus vers. 1.0   
 ───────────────────────────────────────────────  

## Custom animated **Neofetch**.


![Neofetch Demo Gif](../../assets/demo-neofetch.gif)  
---

##  Features
  - Minimal info layout 
  - **Animated Ascii** via `animated-neofetch.sh` 
  - Fast load.

![Neofetch Demo Png](../../assets/demo-neofetch.png)

```
neofetch/  
├── config.conf  
├── myascii.txt  
├── animated-neofetch.sh  
├── frames_colour/  
├── demo.gif  
└── demo.png  
```

## Usage
Add to your `~/.bashrc` or `~/.zshrc` (or whatever shell rc you use):
```
####  Animated Neofetch Splash
if [[ -n $PS1 ]]; then
   ~/.config/neofetch/animated-neofetch.sh 0.05
  clear
fi
```
Frames live in `frames_colour` can be changed to whatever.

**Note:** animated-neofetch.sh caches your neofetch setting for faster load, SO if you make edits please remember to `rm -f ~/.cache/neofetch.txt`.. I'm aware there is fast fetch. 
 

