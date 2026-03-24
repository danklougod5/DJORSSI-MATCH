import urllib.request
try:
    url = "https://raw.githubusercontent.com/Appinio/flutter_card_swiper/master/example/lib/main.dart"
    print(urllib.request.urlopen(url).read().decode('utf-8'))
except Exception as e:
    print(e)
