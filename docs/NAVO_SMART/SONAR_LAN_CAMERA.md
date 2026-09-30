# Sonar / LAN / Camera

LAN-ul este separat de autopilot; căderea rețelei/aplicației nu trebuie să elimine HOLD/RTL sau controlul RC.

Software-ul include transport Ethernet TCP/UDP/reconnect, decoder Kogger, ecogramă, probe geo și pipeline pentru batimetrie/fish detection.

Hardware planificat: Kogger Sonar Basic 2D Plus cu temperatură; cameră IP waterproof RTSP/H.264/MJPEG; switch Ethernet 10/100 și interfață UART/Ethernet unde este necesară. Kogger și camera fizice nu sunt încă validate.

Topologia fizică exactă Kogger/interfață se confirmă din protocolul/manualul hardware-ului ales înainte de cablare. Hardware-ul sonar/cameră se lasă la final.
