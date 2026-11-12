#!/usr/bin/env bash
# Clavis quick emoji picker via fuzzel and wl-copy
set -euo pipefail

EMOJI_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/clavis/emojis.txt"

if [[ ! -f "$EMOJI_FILE" ]]; then
    mkdir -p "$(dirname "$EMOJI_FILE")"
    python3 -c "
import unicodedata

emojis = [
    # Smileys & Emotion
    ('😀', 'grinning face smile'), ('😃', 'grinning face with big eyes happy'),
    ('😄', 'grinning face with smiling eyes joy'), ('😁', 'beaming face with smiling eyes grin'),
    ('😆', 'grinning squinting face laugh'), ('😅', 'grinning face with sweat relief'),
    ('😂', 'face with tears of joy laugh funny lol'), ('🤣', 'rolling on the floor laughing rofl'),
    ('😊', 'smiling face with smiling eyes blush'), ('😇', 'smiling face with halo angel innocent'),
    ('🙂', 'slightly smiling face ok fine'), ('🙃', 'upside down face sarcasm'),
    ('😉', 'winking face flirt joke'), ('😌', 'relieved face peaceful calm'),
    ('😍', 'smiling face with heart eyes love heart'), ('🥰', 'smiling face with hearts affection love'),
    ('😘', 'face blowing a kiss love kiss'), ('😗', 'kissing face'),
    ('😋', 'face savoring food delicious yum'), ('😛', 'face with tongue playful'),
    ('😜', 'winking face with tongue crazy playful'), ('🤪', 'zany face goofy wild'),
    ('😝', 'squinting face with tongue playful'), ('🤑', 'money mouth face rich cash'),
    ('🤗', 'smiling face with open hands hug'), ('🤭', 'face with hand over mouth oops teehee'),
    ('🤫', 'shushing face quiet silence secret'), ('🤔', 'thinking face ponder consider idea'),
    ('🤐', 'zipper mouth face secret silent'), ('🤨', 'face with raised eyebrow skeptical suspect'),
    ('😐', 'neutral face meh plain'), ('😑', 'expressionless face blank deadpan'),
    ('😶', 'face without mouth silent speech'), ('😏', 'smirking face smug flirt'),
    ('😒', 'unamused face annoyed bored'), ('🙄', 'face with rolling eyes eyeroll annoyed'),
    ('😬', 'grimacing face awkward tense'), ('🤥', 'lying face liar pinocchio'),
    ('😌', 'relieved face calm'), ('😔', 'pensive face sad sorrow'),
    ('😪', 'sleepy face tired snooze'), ('🤤', 'drooling face crave delicious'),
    ('😴', 'sleeping face sleep zzz'), ('😷', 'face with medical mask sick doctor'),
    ('🤒', 'face with thermometer fever sick'), ('🤕', 'face with head bandage hurt injured'),
    ('🤢', 'nauseated face sick gross disgusted'), ('🤮', 'face vomiting puke barf'),
    ('🤧', 'sneezing face sneeze allergy sick'), ('🥵', 'hot face sweating summer warm'),
    ('🥶', 'cold face freezing winter ice'), ('🥴', 'woozy face dizzy tipsy intoxicated'),
    ('😵', 'face with crossed out eyes knocked out shock'), ('🤯', 'exploding head mind blown shock amaze'),
    ('🤠', 'cowboy hat face western'), ('🥳', 'partying face party celebrate birthday'),
    ('😎', 'smiling face with sunglasses cool awesome'), ('🤓', 'nerd face geek smart study'),
    ('🧐', 'face with monocle sophisticated curious'), ('😕', 'confused face unsure'),
    ('😟', 'worried face anxious nervous'), ('🙁', 'slightly frowning face sad'),
    ('😮', 'face with open mouth surprise gasp'), ('😯', 'hushed face surprise wow'),
    ('😲', 'astonished face shock amaze'), ('😳', 'flushed face embarrassed blush red'),
    ('🥺', 'pleading face please puppy eyes beg'), ('😦', 'frowning face with open mouth worry'),
    ('😧', 'anguished face pain sorrow'), ('😨', 'fearful face scared shock fright'),
    ('😰', 'anxious face with sweat nervous worry'), ('😥', 'sad but relieved face whew'),
    ('😢', 'crying face tear sad upset'), ('😭', 'loudly crying face sob bawl weeping'),
    ('😱', 'face screaming in fear scream terror shock'), ('😖', 'confounded face upset frustration'),
    ('😣', 'persevering face struggle endure'), ('😞', 'disappointed face let down sad'),
    ('😓', 'downcast face with sweat stress tired'), ('😩', 'weary face tired exasperated'),
    ('😫', 'tired face exhausted frustrated'), ('🥱', 'yawning face tired sleepy bored'),
    ('😤', 'face with steam from nose proud anger win'), ('😡', 'enraged face pouting angry mad fury'),
    ('😠', 'angry face mad irritated'), ('🤬', 'face with symbols on mouth swear curse angry'),
    ('😈', 'smiling face with horns devil evil naughty'), ('👿', 'angry face with horns demon mad evil'),
    ('💀', 'skull dead death skeleton rip lol'), ('☠️', 'skull and crossbones pirate danger death poison'),
    ('💩', 'pile of poo poop crap funny'), ('🤡', 'clown face foolish circus jester'),
    ('👻', 'ghost spooky halloween spirit boo'), ('👽', 'alien extraterrestrial ufo sci fi'),
    ('👾', 'alien monster retro space invader game 8bit'), ('🤖', 'robot bot ai android automaton machine'),

    # Gestures & Hands
    ('👋', 'waving hand wave hello goodbye hi'), ('🤚', 'raised back of hand stop high five'),
    ('🖐️', 'hand with fingers splayed palm stop five'), ('✋', 'raised hand high five paper stop halt'),
    ('🖖', 'vulcan salute spock live long prosper star trek'), ('👌', 'ok hand perfect fine nice approved good'),
    ('🤌', 'pinched fingers italian what do you want gesture'), ('🤏', 'pinching hand small little tiny bit amount'),
    ('✌️', 'victory hand peace two v sign win'), ('🤞', 'crossed fingers luck wish hope promise'),
    ('🤟', 'love you gesture sign language ily rock'), ('🤘', 'sign of the horns rock metal concert music'),
    ('🤙', 'call me hand phone shaka hang loose surf'), ('👈', 'backhand index pointing left point this way'),
    ('👉', 'backhand index pointing right point this way'), ('👆', 'backhand index pointing up look above ceiling'),
    ('👇', 'backhand index pointing down look below floor'), ('☝️', 'index pointing up one point attention number'),
    ('👍', 'thumbs up good like approve yes agree super ok'), ('👎', 'thumbs down bad dislike disapprove no disagree'),
    ('✊', 'raised fist solidarity power punch strength'), ('👊', 'oncoming fist bro fist punch bump attack'),
    ('🤛', 'left facing fist fist bump punch'), ('🤜', 'right facing fist fist bump punch'),
    ('👏', 'clapping hands applause bravo praise clap'), ('🙌', 'raising hands celebration praise hooray yay'),
    ('👐', 'open hands hug welcome honesty'), ('🤲', 'palms up together pray offer request hope'),
    ('🤝', 'handshake agreement deal partner business shake'), ('🙏', 'folded hands please thank you pray namaste bow'),
    ('✍️', 'writing hand pen signature document write note'), ('💅', 'nail polish manicure care style sassy glam'),
    ('🤳', 'selfie camera phone picture photo pose'), ('💪', 'flexed biceps muscle strong arm gym fitness workout power'),

    # Hearts & Symbols
    ('❤️', 'red heart love passion affection romance'), ('🧡', 'orange heart friendship warmth'),
    ('💛', 'yellow heart friendship happiness loyalty'), ('💚', 'green heart nature life health envy'),
    ('💙', 'blue heart trust peace calm cool harmony'), ('💜', 'purple heart luxury royalty charm magic'),
    ('🖤', 'black heart dark sorrow grief mourning gothic'), ('🤍', 'white heart pure peace angel clean'),
    ('🤎', 'brown heart chocolate earthy autumn warmth'), ('💔', 'broken heart heartbreak sad sorrow breakup'),
    ('❣️', 'heart exclamation punctuation love emphasis'), ('💕', 'two hearts romance love cute pink'),
    ('💞', 'revolving hearts love affection tender'), ('💓', 'beating heart love rhythm life passion'),
    ('💗', 'growing heart love fondness expand excitement'), ('💖', 'sparkling heart love sparkle glitter shine'),
    ('💘', 'heart with arrow cupid love romance valentine'), ('💝', 'heart with ribbon gift love valentine present'),
    ('💟', 'heart decoration cute badge symbol'), ('☮️', 'peace symbol anti war harmony hippy'),
    ('✝️', 'latin cross christian christianity church religion'), ('☪️', 'star and crescent islam muslim religion'),
    ('🕉️', 'om hinduism hindu religion sacred chant mantra'), ('☸️', 'wheel of dharma buddhism religion karma law'),
    ('✡️', 'star of david judaism jewish religion israel'), ('🔯', 'six pointed star fortune astrology hexagram'),
    ('🕎', 'menorah jewish hanukkah candlestick candelabrum'), ('☯️', 'yin yang balance harmony taoism dualism'),
    ('☦️', 'orthodox cross christian religion east'), ('🛐', 'place of worship prayer religion sacred altar'),
    ('⛎', 'ophiuchus zodiac serpent horoscope star'), ('♈', 'aries zodiac ram horoscope star sign'),
    ('♉', 'taurus zodiac bull horoscope star sign'), ('♊', 'gemini zodiac twins horoscope star sign'),
    ('♋', 'cancer zodiac crab horoscope star sign'), ('♌', 'leo zodiac lion horoscope star sign'),
    ('♍', 'virgo zodiac maiden horoscope star sign'), ('♎', 'libra zodiac scales horoscope star sign balance'),
    ('♏', 'scorpio zodiac scorpion horoscope star sign'), ('♐', 'sagittarius zodiac archer horoscope star sign'),
    ('♑', 'capricorn zodiac goat horoscope star sign'), ('♒', 'aquarius zodiac water bearer horoscope star sign'),
    ('♓', 'pisces zodiac fish horoscope star sign'), ('🆔', 'id button identification badge card identity'),
    ('⚛️', 'atom symbol science nuclear physics energy atom'), ('☢️', 'radioactive hazard danger nuclear caution warning'),
    ('☣️', 'biohazard danger biological virus plague toxin'), ('📴', 'mobile phone off mute quiet silence silent'),
    ('📳', 'vibration mode phone buzz mobile alert notice'), ('🈶', 'japanese not free of charge button kanji paid'),
    ('🈚', 'japanese free of charge button kanji zero free'), ('🈸', 'japanese application button kanji apply request'),
    ('🈺', 'japanese open for business button kanji open work'), ('🈷️', 'japanese monthly amount button kanji moon month'),
    ('✴️', 'eight pointed star sparkle orange twinkle badge'), ('✳️', 'eight spoked asterisk snowflake flower star green'),
    ('❇️', 'sparkle green star glint shine burst ornament'), ('✨', 'sparkles glitter clean shine magic stars new'),
    ('⚡', 'high voltage electric bolt lightning thunder shock flash power'),
    ('🔥', 'fire flame hot lit burn warm trend blaze popular fire'),
    ('💥', 'collision boom explosion bang blast burst pop crash'),
    ('☄️', 'comet meteor asteroid space falling star cosmos fire'),
    ('🎈', 'balloon party birthday celebration float rubber red'),
    ('🎉', 'party popper celebration celebrate congrats confetti tada party'),
    ('🎊', 'confetti ball celebration congrats party sparkle cheer festival'),
    ('🏆', 'trophy winner champion prize victory award first gold cup'),
    ('🥇', '1st place medal first gold winner prize champion badge'),
    ('🥈', '2nd place medal second silver runner up prize badge'),
    ('🥉', '3rd place medal third bronze prize medal badge'),
    ('⭐', 'star rating favorite gold yellow sky shiny brilliant'),
    ('🌟', 'glowing star shine burst sparkle glitter flare gold'),
    ('💫', 'dizzy star swirl circle light spiral halo spin'),
    ('💯', 'hundred points score perfect exam 100 test ace percent full'),
    ('✅', 'check mark button verify pass ok done approved check confirm yes true'),
    ('❌', 'cross mark cancel reject delete fail error wrong stop no false'),
    ('⚠️', 'warning hazard danger caution alert problem error attention note'),
    ('🚀', 'rocket ship launch speed fast takeoff space boost fly go'),
    ('💡', 'light bulb idea innovation creative solution think bright concept'),
    ('📌', 'pushpin pin map notice board location memo sticky place'),
    ('📍', 'round pushpin map pin location here destination navigation spot gps'),
    ('🎯', 'direct hit bullseye target aim accuracy goal focus shoot archery game'),
    ('🛠️', 'hammer and wrench tool fix repair build settings mechanical settings'),
    ('⚙️', 'gear settings tool options mechanism engine config cog wheel system'),
    ('🔒', 'locked padlock security safe protect privacy access key secure closed'),
    ('🔓', 'unlocked padlock open security privacy release free accessible access'),
    ('🔑', 'key password secret access unlock door security car metal clue solution'),
    ('📦', 'package box parcel delivery post cardboard container product item shipment'),
    ('☕', 'hot beverage coffee tea cup mug cafe morning warm steam drink energy'),
    ('💻', 'laptop computer pc tech screen keyboard coder programming work code web'),
    ('📱', 'mobile phone cell smartphone call tech device screen iphone android text'),
]

with open('$EMOJI_FILE', 'w', encoding='utf-8') as f:
    for em, desc in emojis:
        f.write(f'{em}  {desc}\n')
"
fi

CHOSEN="$(fuzzel --dmenu -p "😀 Emoji: " -l 15 -w 45 < "$EMOJI_FILE" || true)"

if [[ -n "$CHOSEN" ]]; then
    EMOJI="$(echo "$CHOSEN" | awk '{print $1}')"
    printf '%s' "$EMOJI" | wl-copy
    if command -v wtype >/dev/null 2>&1; then
        wtype "$EMOJI" 2>/dev/null || true
    fi
    notify-send -a "Emoji" -i "face-smile" "Emoji Copiado" "$EMOJI se copió al portapapeles."
fi
