# FS25_AnimalHerdingLite

This mod allows all animals to be dynamically herded at will. When they are being herded, animals will walk away from the player, allowing them to be interactively moved between pastures. The Lite version of this mod only handles herding between husbandries, whereas the full version contains more dynamic custom features such as path finding, husbandry navigation, possibility of custom animations, individual behaviours and more, moving the entirety of the visual animal system from the engine to LUA scripts, allowing for much more mod control over animals.

Animals will stop for structures, objects, vehicles and other animals, allowing you to create routes for them to follow, such as in the screenshots provided.

Animals respond to players in vehicles as well as players on foot, allowing the use of vehicles such as quad bikes to herd them. Animals can be moved in the following ways:
- Walking towards them: animals will try to move away from the player
- While holding a feed bucket: animals will try to follow the player
- By being picked up: small/young (or light animals with RealisticLivestock enabled) can be picked up and moved around manually

To start herding, you must be inside a husbandry and then press the "Start Herding" button (default left shift + n). All visual animals in that husbandry will then become herdable and will respond to the player

Herded animals will automatically be moved into a husbandry when they walk inside it, with the exception of the original husbandry where they came from which will only become available for them after leaving the husbandry for a certain amount of time. Alternatively, you can press the "Stop Herding" button, and all herded animals will be moved into the closest husbandry to their current position, if there is one available.

It is not recommended to herd animals in sheds with very high flooring, as the animals may get stuck.

This mod is fully compatible with multiplayer, with the exception of being able to pickup animals.

Compatible with RealisticLivestock, EnhancedAnimalSystem and Animal Package Vanilla Edition

HandTools:
- Feed Bucket: can be purchased in the Animal Tools section of the store
- Animal: approach an animal (herded or not) and press the relevant button in the context menu to pickup a valid animal. Holding an animal prevents the player from switching or toggling handTools until moved into a valid husbandry. Chickens may only be picked up when they are being herded.

<img width="3840" height="2160" alt="fsScreen_2025_11_26_12_59_56-min" src="https://github.com/user-attachments/assets/57779286-c0e0-4d69-8a5c-1e1cdb0613e0" />
<img width="3840" height="2160" alt="fsScreen_2025_11_26_12_00_36-min" src="https://github.com/user-attachments/assets/da411698-e48b-4efb-9900-07e0a7b5eb01" />
<img width="3840" height="2160" alt="fsScreen_2025_11_26_12_00_51-min" src="https://github.com/user-attachments/assets/4eab625a-f40c-49fc-a754-d05c79975070" />
<img width="3840" height="2160" alt="fsScreen_2025_11_26_12_01_09-min" src="https://github.com/user-attachments/assets/5d24301c-2bd8-4f18-84ee-de50d82dcb7d" />
<img width="3840" height="2160" alt="fsScreen_2025_12_03_02_15_10-min" src="https://github.com/user-attachments/assets/fffaacb9-fb2e-4da8-b5d0-7165a610793f" />
