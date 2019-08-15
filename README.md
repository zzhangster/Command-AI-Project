# Command-AI

Ares-Lite is a more practical redesign of the original Ares AI. Instead of creating its own missions sets, the lite version will work with existing user defined missions and parameters. Ares-Light seeks to improve the survivability and effectiveness of assigned units while respecting the mission boundaries set by the user. 

------------------------------
Features:
------------------------------
1.) Categorize units by roles (AAW, AG, ASUW) by their payload and assigned mission. No more reference files. (NEW)

2.) Units will avoid missiles on first detection instead of last possible moment. (OLD)
3.) Updated avoidance to factor in ARH seeker heads. Units will attempt to dive and retreat outside the FOV of ARH missiles. (NEW)
4.) Avoidance behavior based on roles (EX: AAW will avoid SAMS and Ships) (OLD)
5.) Avoidance behavior is divided into two methods. (NEW)
    a.) Line of Sight avoidance - Units will attempt to fly under the radar and still approach threats. To improve fuel efficiency, units will fly at the maximum height possible while avoiding radar. Height values are pre-determined by the distance to horizon equation.
    b.) Hard avoidance - When line of sight avoidance can no longer mask a unit's approach, the unit will attempt to avoid the threat altogether.
6.) Units under Strike Missions will attempt fly under radar to avoid any detected SAMs or ships. They will "Pop-up" only when close to the target. (NEW)
7.) Units under Patrols (SEAD, Land, Anti-ship) will occasionally "Pop-up" to detect and engage targets. (NEW)
8.) Unit avoidance will only trigger on contact detection. The better the ELINT, the better the unit will perform. (NEW)
9.) Ares-Lite will command missions containing the tag "<Ares>" in the mission name. The AI will ignore any missions without the tag. (NEW)
10.) Improved retreat logic. RTB units will now factor their home base when determining retreat vector. (NEW)
11.) Missile threat datum tracking. AI will track missile threats and create "caution zones" for units. (NEW)




