import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

// import createLead from '@salesforce/apex/CustomerEntryController.createLead';
import searchArchitects from '@salesforce/apex/CustomerEntryController.searchArchitects';
import createArchitect from '@salesforce/apex/CustomerEntryController.createArchitect';
import searchCustomers from '@salesforce/apex/CustomerEntryController.searchCustomers';
import searchContractors from '@salesforce/apex/CustomerEntryController.searchContractors';
import createContractor from '@salesforce/apex/CustomerEntryController.createContractor';
import searchMaisons from '@salesforce/apex/CustomerEntryController.searchMaisons';
import createMaison from '@salesforce/apex/CustomerEntryController.createMaison';
import getExecutives from '@salesforce/apex/CustomerEntryController.getExecutives';
import createCustomer from '@salesforce/apex/CustomerEntryController.createCustomer';
import getReferenceTypes from '@salesforce/apex/CustomerEntryController.getReferenceTypes';
import getLeadSources from '@salesforce/apex/CustomerEntryController.getLeadSources';
import checkReferredCustomer from '@salesforce/apex/CustomerEntryController.checkReferredCustomer';
import checkReferralExists from '@salesforce/apex/CustomerEntryController.checkReferralExists';
import getSocialMediaPlatforms from '@salesforce/apex/CustomerEntryController.getSocialMediaPlatforms';
import getCustomerTypes from '@salesforce/apex/CustomerEntryController.getCustomerTypes';

const INDIAN_STATES_CITIES = {
    "Andhra Pradesh": ["Adoni", "Amaravati", "Anantapur", "Chittoor", "Eluru", "Guntur", "Kadapa",
        "Kakinada", "Kurnool", "Nellore", "Ongole", "Rajahmundry", "Srikakulam",
        "Tirupati", "Vijayawada", "Visakhapatnam", "Vizianagaram"],
    "Arunachal Pradesh": ["Itanagar", "Naharlagun", "Pasighat", "Tawang", "Ziro"],
    "Assam": ["Dibrugarh", "Dispur", "Guwahati", "Jorhat", "Silchar", "Tezpur", "Tinsukia"],
    "Bihar": ["Arrah", "Bhagalpur", "Bihar Sharif", "Darbhanga", "Gaya", "Muzaffarpur",
        "Patna", "Purnia", "Samastipur", "Sasaram"],
    "Chhattisgarh": ["Ambikapur", "Bhilai", "Bilaspur", "Durg", "Jagdalpur", "Korba", "Raigarh", "Raipur"],
    "Goa": ["Bicholim", "Canacona", "Mapusa", "Margao", "Mormugao", "Panaji", "Ponda"],
    "Gujarat": ["Ahmedabad", "Amreli", "Anand", "Bhavnagar", "Bhuj", "Gandhinagar", "Jamnagar",
        "Junagadh", "Mehsana", "Rajkot", "Surat", "Vadodara"],
    "Haryana": ["Ambala", "Faridabad", "Gurugram", "Hisar", "Karnal", "Kurukshetra", "Panipat", "Rohtak", "Yamunanagar"],
    "Himachal Pradesh": ["Bilaspur", "Chamba", "Dharamshala", "Hamirpur", "Kullu", "Mandi", "Shimla", "Solan"],
    "Jharkhand": ["Bokaro", "Deoghar", "Dhanbad", "Dumka", "Giridih", "Hazaribagh", "Jamshedpur", "Ranchi"],
    "Karnataka": ["Bagalkot", "Ballari", "Belagavi", "Bengaluru", "Bidar", "Chikmagalur", "Davanagere",
        "Hassan", "Hubballi", "Kalaburagi", "Mangaluru", "Mysuru", "Shivamogga", "Tumakuru", "Udupi"],
    "Kerala": ["Alappuzha", "Ernakulam", "Idukki", "Kannur", "Kasaragod", "Kollam", "Kottayam",
        "Kozhikode", "Malappuram", "Palakkad", "Pathanamthitta", "Thiruvananthapuram", "Thrissur"],
    "Madhya Pradesh": ["Bhopal", "Dewas", "Gwalior", "Indore", "Jabalpur", "Khandwa", "Rewa", "Sagar", "Satna", "Ujjain"],
    "Maharashtra": ["Ahmednagar", "Aurangabad", "Kolhapur", "Mumbai", "Nagpur", "Nashik", "Pune",
        "Solapur", "Thane", "Amravati", "Latur", "Satara", "Sangli"],
    "Manipur": ["Bishnupur", "Chandel", "Churachandpur", "Imphal", "Senapati", "Tamenglong", "Ukhrul"],
    "Meghalaya": ["Shillong", "Tura", "Jowai", "Baghmara", "Williamnagar"],
    "Mizoram": ["Aizawl", "Lunglei", "Champhai", "Serchhip"],
    "Nagaland": ["Dimapur", "Kohima", "Mokokchung", "Mon", "Phek", "Tuensang", "Zunheboto"],
    "Odisha": ["Balasore", "Bargarh", "Berhampur", "Bhubaneswar", "Cuttack", "Puri", "Rourkela", "Sambalpur"],
    "Punjab": ["Amritsar", "Barnala", "Bathinda", "Ferozepur", "Jalandhar", "Ludhiana", "Mansa", "Patiala"],
    "Rajasthan": ["Ajmer", "Bikaner", "Jaipur", "Jaisalmer", "Jodhpur", "Kota", "Udaipur"],
    "Sikkim": ["Gangtok", "Gyalshing", "Mangan", "Namchi"],
    "Tamil Nadu": ["Chennai", "Coimbatore", "Erode", "Madurai", "Salem", "Tiruchirappalli", "Tirunelveli", "Vellore"],
    "Telangana": ["Adilabad", "Hyderabad", "Karimnagar", "Khammam", "Mahbubnagar", "Nalgonda", "Nizamabad", "Warangal"],
    "Tripura": ["Agartala", "Dharmanagar", "Udaipur"],
    "Uttar Pradesh": ["Agra", "Aligarh", "Allahabad", "Bareilly", "Ghaziabad", "Gorakhpur", "Jhansi", "Kanpur",
        "Lucknow", "Meerut", "Moradabad", "Noida", "Saharanpur", "Varanasi"],
    "Uttarakhand": ["Almora", "Dehradun", "Haridwar", "Nainital", "Pauri", "Rishikesh", "Roorkee", "Tehri"],
    "West Bengal": ["Asansol", "Bardhaman", "Darjeeling", "Durgapur", "Howrah", "Kolkata", "Siliguri"],
    "Andaman and Nicobar Islands": ["Port Blair"],
    "Chandigarh": ["Chandigarh"],
    "Dadra and Nagar Haveli and Daman and Diu": ["Daman", "Diu", "Silvassa"],
    "Lakshadweep": ["Kavaratti"],
    "Delhi": ["New Delhi", "Central Delhi", "East Delhi", "West Delhi", "North Delhi", "South Delhi"],
    "Puducherry": ["Karaikal", "Mahe", "Puducherry", "Yanam"]
};

const KERALA_PANCHAYATS = {
    "Kasaragod": [
        "Ajanur", "Badiadka", "Balal", "Bedadka", "Belloor", "Chemnad", "Chengala", "Cheruvathur",
        "Delampady", "East Eleri", "Enmakaje", "Kallar", "Karadka", "Kayyur Cheemeni", "Kinanoor - Karinthalam",
        "KodomBelur", "Kumbadaje", "Kumbla", "Kuttikol", "Madhur", "Madikai", "Mangalpady", "Manjeshwar",
        "Meenja", "MogralPuthur", "Muliyar", "Padne", "Paivalike", "Pallikere", "Panathady", "Pilicode",
        "PullurPeriya", "Puthige", "Trikaripur", "Udma", "Valiyaparamba", "Vorkady", "WestEleri",
        "Manjeshwar", "Karadka", "Kasaragod", "Kanhangad", "Parappa", "Nileshwar"
    ],
    "Kannur": [
        "Alakode", "Anjarakandy", "Aralam", "Ayyankunnu", "Azhikode", "Chapparapadava", "Chembilode",
        "Chengalayi", "Cherukunnu", "Cherupuzha", "Cheruthazham", "Chirakkal", "Chittariparamba", "Chokli",
        "Dharmadam", "Eramam Kuttur", "Eranholi", "Eruvessy", "Ezhome", "Irikkur", "Kadambur",
        "Kadannappally Panapuzha", "Kadirur", "Kalliasseri", "Kanichar", "Kankol-Alappadamba",
        "Kannapuram", "Karivellur-Peralam", "Keezhallur", "Kelakam", "Kolachery", "Kolayad", "Koodali",
        "Kottayam", "Kottiyoor", "Kunhimangalam", "Kunnothuparamba", "Kurumathur", "Kuttiattoor", "Madayi",
        "Malappattam", "Malur", "Mangattidam", "Mattool", "Mayyil", "Mokeri", "Munderi", "Muzhakkunnu",
        "Muzhappilangad", "Naduvil", "Narath", "New-Mahe", "Padiyoor", "Panniyannur", "Pappinisseri",
        "Pariyaram", "Pattiam", "Pattuvam", "Payam", "Payyavoor", "Peralassery", "Peravoor",
        "Peringome Vayakkara", "Pinarayi", "Ramanthali", "Thillankery", "Triprangottoor", "Udayagiri",
        "Ulikkal", "Valapattanam", "Vengad", "Payyannur", "Kalliasseri", "Taliparamba", "Irikkur", "Kannur", "Edakkad", "Thalassery", "Panoor", "Kuthuparamba", "Iritty", "Peravoor"
    ],
    "Wayanad": [
        "Ambalavayal", "Edavaka", "Kaniyambetta", "Kottathara", "Meenangadi", "Meppadi", "Mullankolly",
        "Muppainad", "Muttil", "Nenmeni", "Noolpuzha", "Padinharathara", "Panamaram", "Poothadi",
        "Pozhuthana", "Pulpally", "Thariode", "Thavinhal", "Thirunelly", "Thondernad", "Vellamunda",
        "Vengappally", "Vythiri", "Mananthavady", "Panamaram", "Sulthan Bathery", "Kalpetta"
    ],
    "Kozhikode": [
        "Arikkulam", "Atholi", "Ayancheri", "Azhiyur", "Balussery", "Chakkittapara", "Changaroth",
        "Chathamangalam", "Chekkiad", "Chelannur", "Chemanchery", "Chengottukavu", "Cheruvannur",
        "Chorode", "Edacheri", "Eramala", "Kadalundi", "Kakkodi", "Kakkur", "Karassery", "Kattippara",
        "Kavilumpara", "Kayakkody", "Kayanna", "Keezhariyur", "Kizhakkoth", "Kodanchery", "Kodiyathur",
        "Koodaranhi", "Koorachundu", "Koothali", "Kottur", "Kunnamangalam", "Kunnummal", "Kuruvattoor",
        "Kuttiadi", "Madavoor", "Maniyur", "Maruthonkara", "Mavoor", "Meppayur", "Moodadi", "Nadapuram",
        "Naduvannur", "Nanminda", "Narikunni", "Narippatta", "Nochad", "Olavanna", "Omassery",
        "Onchiyam", "Panangad", "Perambra", "Perumanna", "Peruvayal", "Puduppady", "Purameri",
        "Thalakulathur", "Thamarassery", "Thikkodi", "Thiruvallur", "Thiruvambadi", "Thurayur",
        "Tuneri", "Ulliyeri", "Unnikulum", "Valayam", "Vanimal", "Velom", "Villiappally",
        "Vatakara", "Tuneri", "Kunnummal", "Thodannur", "Melady", "Perambra", "Balussery", "Panthalayani", "Chelannur", "Koduvally", "Kunnamangalam", "Kozhikkode"
    ],
    "Malappuram": [
        "Alamkode", "Aliparamba", "Amarambalam", "Anakkayam", "Angadippuram", "Areacode", "ARNagar",
        "Athavanad", "Chaliyar", "Cheacode", "Chelembra", "Cheriyamundam", "Cherukavu", "Chokkad",
        "Chungathara", "Edakkara", "Edapal", "Edappatta", "Edarikode", "Edavanna", "Edayur",
        "Elamkulam", "Irimbiliyam", "Kaladi", "Kalikavu", "Kalpakanchery", "Kannamangalam", "Karulai",
        "Karuvarakundu", "Kavanur", "Keezhattur", "Keezhuparamba", "Kodur", "Koottilangadi", "Kuruva",
        "Kuttippuram", "Kuzhimanna", "Makkaraparamba", "Mampad", "Mangalam", "Mankada", "Marakkara",
        "Maranchery", "Melattur", "Moonniyur", "Moorkkanad", "Moothedam", "Morayur", "Muthuvalloor",
        "Nannambra", "Nannammukku", "Niramaruthur", "Oorakam", "Othukkungal", "Ozhur", "Pallikkal",
        "Pandikkad", "Parappur", "Perumanna", "Perumpadappa", "Peruvalloor", "Ponmala", "Ponmundam",
        "Pookkottur", "Porur", "Pothukallu", "Pulamanthole", "Pulikkal", "Pulpatta", "Purathur",
        "Puzhakkattiri", "Tanalur", "Tavanur", "Thalakkad", "Thazhekkode", "Thenhipalam", "Thennala",
        "Thirunavaya", "Thiruvali", "Thrikkalangodu", "Triprangode", "Tuvvur", "Urangattiri",
        "Valavannur", "Vallikkunnu", "Vattamkulam", "Vazhakkad", "Vazhayur", "Vazhikkadavu",
        "Veliancode", "Vengara", "Vettathur", "Vettom", "Wandoor", "Nilambur", "Kalikavu", "Wandoor", "Kondotty", "Areacode", "Malappuram", "Perinthalmanna", "Mankada", "Kuttippuram", "Vengara", "Tirurangadi", "Tanur", "Tirur", "Ponnani", "Perumpadappa"
    ],
    "Palakkad": [
        "Agali", "Akathethara", "Alanallur", "Alathur", "Ambalappara", "Anakkara", "Ananganadi",
        "Ayiloor", "Chalavara", "Chalissery", "Elappully", "Elavancherry", "Erimayur", "Eruthenpathy",
        "Kadampazhipuram", "Kanhirapuzha", "Kannadi", "Kannambra", "Kappur", "Karakurussi", "Karimba",
        "Karimpuzha", "Kavassery", "Keralassery", "Kizhakkencherry", "Kodumbu", "Koduvayur", "Kollengode",
        "Kongad", "Koppam", "Kottayi", "Kottopadam", "Kozhinjampara", "Kulukkallur", "Kumaramputhur",
        "Kuthanur", "Kuzhalmannam", "Lakkidi-Perur", "Malampuzha", "Mankara", "Mannur", "Marutharode",
        "Mathur", "Melarcode", "Mundur", "Muthalamada", "Muthuthala", "Nagalassery", "Nallepilly",
        "Nellaya", "Nelliyampathy", "Nenmara", "Ongallur", "Pallassana", "Parali", "Paruthur",
        "Pattanchery", "Pattithara", "Peringottukurissi", "Perumatty", "Peruvemba", "Pirayiri",
        "Polpully", "Pookkottukavu", "Puducode", "Pudunagaram", "Puduppariyaram", "Pudur", "Pudusseri",
        "Sholayoor", "Sreekrishnapuram", "Tachampara", "Tarur", "Thachanattukara", "Thenkara",
        "Thenkurissi", "Thirumittacode", "Thiruvegappura", "Trikkaderi", "Trithala", "Vadakarapathy",
        "Vadakkencheri", "Vadavannur", "Vallapuzha", "Vandazhy", "Vaniamkulam", "Vellinezhi", "Vilayur",
        "Trithala", "Pattambi", "Ottapalam", "Sreekrishnapuram", "Mannarkad", "Attappady", "Palakkad", "Kuzhalmannam", "Chittur", "Kollengode", "Nemmara", "Alathur", "Malampuzha"
    ],
    "Thrissur": [
        "Adat", "Alagappanagar", "Aloor", "Annamanada", "Anthikad", "Arimpur", "Athirappilly",
        "Avanur", "Avinissery", "Chazhur", "Chelakkara", "Cherpu", "Choondal", "Chowannur",
        "Desamangalam", "Edathiruthy", "Edavilangu", "Elavally", "Engandiyur", "Eriyad", "Erumapetty",
        "Kadangode", "Kadappuram", "Kadavallur", "Kadukutty", "Kaipamangalam", "Kaiparambu",
        "Kandanassery", "Karalam", "Kattakampal", "Kattoor", "Kodakara", "Kodassery", "Kolazhy",
        "Kondazhy", "Koratty", "Kuzhur", "Madakkathara", "Mala", "Manalur", "Mathilakam", "Mattathur",
        "Meloor", "Mulakunnathukavu", "Mullassery", "Mullurkara", "Muriyad", "Nadathara", "Nattika",
        "Nenmanikkara", "Orumanayur", "Padiyoor", "Pananchery", "Panjal", "Paralam", "Parappukkara",
        "Pariyaram", "Pavaratty", "Pazhayannur", "Perinjanam", "Poomangalam", "Porkulam", "Poyya",
        "Pudukad", "Punnayur", "Punnayurkulam", "Puthenchira", "Puthur", "Sreenarayanapuram",
        "Thalikulam", "Thanniyam", "Thekkumkara", "Thiruvilwamala", "Tholur", "Thrikkur", "Vadakkekkad",
        "Valapad", "Vallachira", "VallatholNagar", "Varandarappilly", "Varavoor", "Vatanapally",
        "Vellangallur", "Velukara", "Velur", "Venkitangu", "Chavakkad", "Chowannur", "Wadakanchery", "Pazhayannur", "Ollukkara", "Puzhakkal", "Mullassery", "Thalikulam", "Anthikad", "Cherpu", "Kodakara", "Irinjalakuda", "Vellangallur", "Mathilakam", "Mala", "Chalakudy"
    ],
    "Ernakulam": [
        "Aikaranad", "Alangad", "Amballoor", "Arakuzha", "Asamannoor", "Avoly", "Ayavana",
        "Ayyampuzha", "Chellanam", "Chendamangalam", "Chengamanad", "Cheranalloor", "Chittattukara",
        "Choornikkara", "Chottanikkara", "Edakkattuvayal", "Edathala", "Edavanakkad", "Elanji",
        "Elankunnapuzha", "Ezhikkara", "Kadamakudy", "Kadungalloor", "Kalady", "Kalloorkad", "Kanjoor",
        "Karukutty", "Karumallur", "Kavalangad", "Keerampara", "Keezhmad", "Kizhakkambalam", "Koovappady",
        "Kottappady", "Kottuvally", "Kumbalam", "Kumbalanghi", "Kunnathunad", "Kunnukara", "Kuttampuzha",
        "Kuzhuppilly", "MalayattoorNeeleswaram", "Maneed", "Manjalloor", "Manjapra", "Marady",
        "Mazhuvannoor", "Mookkannur", "Mudakuzha", "Mulanthuruthy", "Mulavukad", "Narakal", "Nayarambalam",
        "Nedumbassery", "Nellikuzhi", "Okkal", "Paingottoor", "Paipra", "Palakuzha", "Pallarimangalam",
        "Pallippuram", "Pampakuda", "Parakkadavu", "Pindimana", "Poothrikka", "Pothanicad",
        "Puthenvelikkara", "Ramamangalam", "Rayamangalam", "Sreemoolanagaram", "Thirumarady",
        "Thiruvaniyoor", "Thuravoor", "Udayamperoor", "Vadakkekkara", "VadavucodePuthencruz", "Valakom",
        "Varappetty", "Varapuzha", "Vazhakulam", "Vengola", "Vengoor", "Paravur", "Alangad", "Angamaly", "Koovappady", "Vazhakulam", "Edappally", "Vypin", "Palluruthy", "Peravoor"
    ],
    "Kottayam": [
        "Akalakunnam", "Arpookara", "Athirampuzha", "Ayarkunnam", "Aymanam", "Bharananganam", "Chempu",
        "Chirakkadavu", "Elikulam", "Erumely", "Kadanad", "Kadaplamattom", "Kaduthuruthy", "Kallara",
        "Kanakkary", "Kangazha", "Kanjirappally", "Karoor", "Karukachal", "Kidangoor", "Kooroppada",
        "Koottickal", "Koruthodu", "Kozhuvanal", "Kumarakom", "Kuravilangad", "Kurichy", "Madappally",
        "Manarcadu", "Manimala", "Manjoor", "Marangattupilly", "Maravanthuruthu", "Meenachil", "Meenadom",
        "Melukavu", "Moonnilavu", "Mulakulam", "Mundakayam", "Mutholy", "Nedumkunnam", "Neendoor",
        "Neezhoor", "Paippad", "Pallickathodu", "Pampady", "Panachikkad", "Parathodu", "Poonjar",
        "Thekkekara", "Puthuppally", "Ramapuram", "Teekoy", "Thalanad", "Thalappalam", "Thalayazham",
        "Thalayolaparambu", "Thidanad", "Thiruvarppu", "Thrickodithanam", "TV Puram", "Udayanapuram",
        "Uzhavoor", "Vakathanam", "Vazhappally", "Vazhoor", "Vechoor", "Veliyannoor", "Vellavoor",
        "Velloor", "Vijayapuram", "Vaikom", "Kaduthuruthy", "Ettumanoor", "Uzhavoor", "Lalam", "Erattupetta", "Pampady", "Pallom", "Madappally", "Vazhoor", "Kanjirappally"
    ],
    "Alappuzha": [
        "Ala", "Ambalapuzha", "Arattupuzha", "Arookutty", "Aroor", "Aryad", "Bharanickavu", "Budhanoor",
        "Champakulam", "Chennam- Pallippuram", "Chennithala-Thripperumthura", "Cheppad", "Cheriyanad",
        "Cherthala", "Cheruthana", "Chettikulangara", "Chingoli", "Chunakara", "Devikulangara", "Edathua",
        "Ezhupunna", "Kadakkarappally", "Kainakary", "Kandalloor", "Kanjikuzhy", "Karthikappally",
        "Karuvatta", "Kavalam", "Kodamthuruth", "Krishnapuram", "Kumarapuram", "Kuthiathod", "Mannancherry",
        "Mannar", "Mararikulam", "Mararikulam", "Mavelikara-Thamarakulam", "Mavelikara-Thekkekara",
        "Muhamma", "Mulakuzha", "Muthukulam", "Muttar", "Nedumudi", "Neelamperoor", "Nooranad", "Palamel",
        "Pallippad", "Panavally", "Pandanad", "Pathiyoor", "Pattanakkad", "Perumpalam", "Pulincunnoo",
        "Puliyoor", "Punnapra", "Purakkad", "Ramankary", "Thakazhy", "Thalavady", "Thanneermukkom",
        "Thazhakara", "Thiruvanvandoor", "Thrikkunnappuzha", "Thuravoor", "Thycattussery", "Vallikunnam",
        "Vayalar", "Veeyapuram", "Veliyanad", "Venmoney", "Thycattussery", "Pattanakkad", "Kanjikuzhy", "Aryad", "Ambalappuzha", "Champakulam", "Veliyanad", "Chengannur", "Haripad", "Mavelikara", "Bharanickavu", "Muthukulam"
    ],
    "Pathanamthitta": [
        "Anicadu", "Aranmula", "Aruvappulam", "Ayroor", "Chenneerkara", "Cherukole", "Chittar",
        "Elanthoor", "Enadimangalam", "Erathu", "Eraviperoor", "Ezhumattoor", "Kadampanad",
        "Kadapra", "Kalanjoor", "Kallooppara", "Kaviyoor", "Kodumon", "Koipuram", "Konni", "Kottanad",
        "Kottangal", "Kozhencherry", "Kulanada", "Kunnamthanam", "Kuttoor", "Malayalapuzha", "Mallappally",
        "Mallappuzhassery", "Mezhuveli", "Mylapra", "Naranammoozhy", "Naranganam", "Nedumpuram",
        "Niranam", "Omalloor", "Pallickal", "Pandalam Thekkekara", "Peringara", "Pramadom", "Puramattom",
        "Ranni Angadi", "Ranni", "Ranni Pazhavangadi", "Ranni Perunadu", "Seethathodu", "Thannithodu",
        "Thottappuzhassery", "Thumpamon", "Vadaserikara", "Vallicode", "Vechoochira", "Mallappally", "Pulikeezhu", "Koipuram", "Elanthoor", "Ranni", "Konni", "Pandalam", "Parakkode"
    ],
    "Kollam": [
        "Adichanalloor", "Alappad", "Alayamon", "Anchal", "Aryankavu", "Chadayamangalam", "Chathannoor",
        "Chavara", "Chirakkara", "Chithara", "Clappana", "East Kallada", "Edamulackal", "Elamadu",
        "Elampalloor", "Ezhukone", "Ittiva", "Kadakkal", "Kalluvathukkal", "Karavaloor", "Kareepra",
        "Kottamkara", "Kulakkada", "Kulasekharapuram", "Kulathupuzha", "Kummil", "Kundara", "Kunnathoor",
        "Mayyanad", "Melila", "Munroethuruth", "Mylom", "Mynagappally", "Nedumpana", "Neduvathoor",
        "Neendakara", "Nilamel", "Oachira", "Panayam", "Panmana", "Pathanapuram", "Pattazhi",
        "Pattazhi-Vadakkekara", "Pavithreswaram", "Perayam", "Perinad", "Piravanthoor", "Poothakulam",
        "Pooyappally", "Poruvazhy", "Sasthamcotta", "Sooranad", "Thalavoor", "Thazhava", "Thekkumbhagom",
        "Thenmala", "Thevalakkara", "Thodiyoor", "Thrikkaruva", "Thrikkovilvattom", "Ummannoor",
        "Velinalloor", "Veliyam", "Vettikavala", "Vilakkudy", "West Kallada", "Yeroor", "Oachira", "Sasthamcotta", "Vettikavala", "Pathanapuram", "Anchal", "Kottarakara", "Chittumala", "Chavara", "Mukhathala", "Ithikkara", "Chadayamangalam"
    ],
    "Thiruvananthapuram": [
        "Amboori", "Anad", "Anchuthengu", "Andoorkonam", "Aruvikkara", "Aryanad", "Aryancode",
        "Athiyannoor", "Azhoor", "Balaramapuram", "Chemmaruthy", "Chenkal", "Cherunniyoor",
        "Chirayinkeezhu", "Edava", "Elakamon", "Kadakkavoor", "Kadinamkulam", "Kallara", "Kallikkadu",
        "Kalliyoor", "Kanjiramkulam", "Karakulam", "Karavaram", "Karode", "Karumkulam", "Kattakada",
        "Kilimanoor", "Kizhuvilam", "Kollayil", "Kottukal", "Kulathoor", "Kunnathukal", "Kuttichal",
        "Madavoor", "Malayinkeezh", "Manamboor", "Mangalapuram", "Manickal", "Maranalloor", "Mudakkal",
        "Nagaroor", "Nanniyode", "Navaikulam", "Nellanad", "Ottasekharamangalam", "Ottoor", "Pallichal",
        "Pallickal", "Panavoor", "Pangode", "Parassala", "Pazhayakunnumel", "Peringammala",
        "Perumkadavila", "Poovachal", "Poovar", "Pothencode", "Pulimath", "Pullampara", "Thirupuram",
        "Tholicode", "Uzhamalakkal", "Vakkom", "Vamanapuram", "Vellanad", "Vellarada", "Vembayam",
        "Venganoor", "Vettoor", "Vilappil", "Vilavoorkal", "Vithura", "Varkala", "Kilimanoor", "Chirayinkeezh", "Vamanapuram", "Vellanad", "Nedumangad", "Pothencode", "Nemom", "Perumkadavila", "Athiyannoor", "Parassala"
    ],
    "Idukki": [
        "Adimaly", "Alakode", "Arakulam", "AyyappanCoil", "BysonValley", "Chakkupallam", "Chinnakanal", "Devikulam", "Edamalakkudy", "Edavetty", "Elappara", "Erattaayar", "IdukkiKanjikuzhy", "Kamakshy", "Kanchiyar", "Kanthalloor", "Karimannoor", "Karimkunnam", "Karunapuram", "Kodikulam", "Kokkayar", "Konnathady", "Kudayathoor", "Kumaramangalam", "Kumily", "Manakkad", "Mankulam", "Marayoor", "Mariyapuram", "Munnar", "Muttom", "Nedumkandam", "Pallivasal", "Pampadumpara", "Peermade", "Peruvanthanam", "Purapuzha", "Rajakkad", "Rajakumary", "Santhanpara", "Senapathy", "Udumbanchola", "Udumbanoor", "Upputhara", "Vandanmedu", "Vandiperiyar", "Vannappuram", "Vathikudy", "Vattavada", "Vazhathope", "Vellathooval", "Velliyamattom", "Adimaly", "Devikulam", "Nedumkandam", "Elemdesam", "Idukki", "Kattappana", "Thodupuzha", "Azhutha"
    ]
};

const STATE_CODES = {
    "Andhra Pradesh": "AP",
    "Arunachal Pradesh": "AR",
    "Assam": "AS",
    "Bihar": "BR",
    "Chhattisgarh": "CG",
    "Goa": "GA",
    "Gujarat": "GJ",
    "Haryana": "HR",
    "Himachal Pradesh": "HP",
    "Jharkhand": "JH",
    "Karnataka": "KA",
    "Kerala": "KL",
    "Madhya Pradesh": "MP",
    "Maharashtra": "MH",
    "Manipur": "MN",
    "Meghalaya": "ML",
    "Mizoram": "MZ",
    "Nagaland": "NL",
    "Odisha": "OR",
    "Punjab": "PB",
    "Rajasthan": "RJ",
    "Sikkim": "SK",
    "Tamil Nadu": "TN",
    "Telangana": "TG",
    "Tripura": "TR",
    "Uttar Pradesh": "UP",
    "Uttarakhand": "UK",
    "West Bengal": "WB",
    "Andaman and Nicobar Islands": "AN",
    "Chandigarh": "CH",
    "Dadra and Nagar Haveli and Daman and Diu": "DN",
    "Lakshadweep": "LD",
    "Delhi": "DL",
    "Puducherry": "PY"
};

const COUNTRY_PHONE_RULES = {
    IN: { name: 'India', min: 10, max: 10, code: '+91' },
    US: { name: 'United States', min: 10, max: 10, code: '+1' },
    GB: { name: 'United Kingdom', min: 10, max: 10, code: '+44' },
    AU: { name: 'Australia', min: 9, max: 9, code: '+61' },
    CA: { name: 'Canada', min: 10, max: 10, code: '+1' },
    SG: { name: 'Singapore', min: 8, max: 8, code: '+65' },
    AE: { name: 'United Arab Emirates', min: 9, max: 9, code: '+971' },
    DE: { name: 'Germany', min: 10, max: 11, code: '+49' },
    FR: { name: 'France', min: 9, max: 9, code: '+33' },
    IT: { name: 'Italy', min: 9, max: 10, code: '+39' },
    ES: { name: 'Spain', min: 9, max: 9, code: '+34' },
    CN: { name: 'China', min: 11, max: 11, code: '+86' },
    JP: { name: 'Japan', min: 10, max: 11, code: '+81' },
    RU: { name: 'Russia', min: 10, max: 10, code: '+7' },
    BR: { name: 'Brazil', min: 10, max: 11, code: '+55' },
    ZA: { name: 'South Africa', min: 9, max: 9, code: '+27' },
    PK: { name: 'Pakistan', min: 10, max: 11, code: '+92' },
    BD: { name: 'Bangladesh', min: 10, max: 10, code: '+880' },
    LK: { name: 'Sri Lanka', min: 9, max: 9, code: '+94' },
    NP: { name: 'Nepal', min: 10, max: 10, code: '+977' },
    SA: { name: 'Saudi Arabia', min: 9, max: 9, code: '+966' },
    MY: { name: 'Malaysia', min: 9, max: 10, code: '+60' },
    TH: { name: 'Thailand', min: 9, max: 9, code: '+66' },
    ID: { name: 'Indonesia', min: 10, max: 12, code: '+62' },
    PH: { name: 'Philippines', min: 10, max: 10, code: '+63' },
    NG: { name: 'Nigeria', min: 10, max: 11, code: '+234' },
    EG: { name: 'Egypt', min: 10, max: 10, code: '+20' },
    TR: { name: 'Turkey', min: 10, max: 10, code: '+90' },
    MX: { name: 'Mexico', min: 10, max: 10, code: '+52' },
    AR: { name: 'Argentina', min: 10, max: 10, code: '+54' },
    KR: { name: 'South Korea', min: 9, max: 10, code: '+82' },
    PL: { name: 'Poland', min: 9, max: 9, code: '+48' },
    NL: { name: 'Netherlands', min: 9, max: 9, code: '+31' },
    BE: { name: 'Belgium', min: 9, max: 9, code: '+32' },
    SE: { name: 'Sweden', min: 9, max: 9, code: '+46' },
    CH: { name: 'Switzerland', min: 9, max: 9, code: '+41' },
    AT: { name: 'Austria', min: 10, max: 13, code: '+43' },
    DK: { name: 'Denmark', min: 8, max: 8, code: '+45' },
    NO: { name: 'Norway', min: 8, max: 8, code: '+47' },
    FI: { name: 'Finland', min: 9, max: 10, code: '+358' },
    IE: { name: 'Ireland', min: 9, max: 9, code: '+353' },
    NZ: { name: 'New Zealand', min: 9, max: 9, code: '+64' },
    IL: { name: 'Israel', min: 9, max: 9, code: '+972' },
    GR: { name: 'Greece', min: 10, max: 10, code: '+30' },
    PT: { name: 'Portugal', min: 9, max: 9, code: '+351' },
    HU: { name: 'Hungary', min: 9, max: 9, code: '+36' },
    CZ: { name: 'Czech Republic', min: 9, max: 9, code: '+420' },
    RO: { name: 'Romania', min: 10, max: 10, code: '+40' },
    SK: { name: 'Slovakia', min: 9, max: 9, code: '+421' },
    BG: { name: 'Bulgaria', min: 9, max: 9, code: '+359' },
    HR: { name: 'Croatia', min: 9, max: 9, code: '+385' },
    SI: { name: 'Slovenia', min: 9, max: 9, code: '+386' },
    EE: { name: 'Estonia', min: 7, max: 8, code: '+372' },
    LT: { name: 'Lithuania', min: 8, max: 8, code: '+370' },
    LV: { name: 'Latvia', min: 8, max: 8, code: '+371' },
    LU: { name: 'Luxembourg', min: 9, max: 9, code: '+352' },
    MT: { name: 'Malta', min: 8, max: 8, code: '+356' },
    CY: { name: 'Cyprus', min: 8, max: 8, code: '+357' },
    IS: { name: 'Iceland', min: 7, max: 7, code: '+354' },
    MC: { name: 'Monaco', min: 8, max: 8, code: '+377' },
    LI: { name: 'Liechtenstein', min: 7, max: 7, code: '+423' },
    SM: { name: 'San Marino', min: 10, max: 10, code: '+378' },
    VA: { name: 'Vatican City', min: 9, max: 9, code: '+379' }
};

export default class CustomerEntryForm extends NavigationMixin(LightningElement) {
    @track customerData = {
        salutation: '',
        firstName: '',
        lastName: '',
        company: '',
        primaryPhone: '',
        secondaryPhone: '',
        email: '',
        street: '',
        state: '',
        district: '',
        pinCode: '',
        country: '',
        customerSource: '',
        referenceType: '',
        referenceArchitect: '',
        customerId: '',
        leadType: '',
        leadPurpose: '',
        customerEntryDate: new Date().toISOString().split('T')[0],
        assignedExecutive: '',
        remarks: '',
        referralName: '',
        phoneNumber: '',
        socialMedia: '',
        type: '',
        pocName: '',
        pocContactNo: '',
        pocEmail: '',
        panchayat: '',
    };
    
    // Add getter for minimum date
    get minDate() {
        return new Date().toISOString().split('T')[0];
    }
    
    @track executives = [];
    
    // Toast properties
    @track showToast = false;
    @track toastTitle = '';
    @track toastMessage = '';
    @track toastVariant = 'success'; // success, error, warning, info
    
    // Add a loading state property
    @track isLoading = false;
    
    // Reference search properties
    @track showReferenceFields = false;
    @track showArchitectFields = false;
    @track showCustomerFields = false;
    @track showContractorFields = false;
    @track showMaisonFields = false;
    @track showPhoneNumberField = false;
    @track showReferralNameField = false;
    @track showCustomerReferenceFields = false;

    @track architectSearchTerm = '';
    @track customerSearchTerm = '';
    @track contractorSearchTerm = '';
    @track maisonSearchTerm = '';

    @track architectSearchResults = [];
    @track customerSearchResults = [];
    @track contractorSearchResults = [];
    @track maisonSearchResults = [];

    @track showArchitectResults = false;
    @track showCustomerResults = false;
    @track showContractorResults = false;
    @track showMaisonResults = false;

    @track showAddNewOption = false;
    @track showAddNewContractorOption = false;
    @track showAddNewMaisonOption = false;

    // Modal properties for new entries
    @track showNewArchitectModal = false;
    @track showNewContractorModal = false;
    @track showNewMaisonModal = false;

    @track newArchitectData = { name: '', phoneNumber: '' };
    @track newContractorData = { name: '' };
    @track newMaisonData = { name: '' };

    @track noCustomerResults = false;

    @track citiesList = [];
    isCityDisabled = true;

    @track referenceTypes = [];
    @track leadSources = [];
    @track customerTypes = [];

    @track showReferralNameInput = false;
    @track referredCustomerExists = false;
    @track referredCustomerName = '';

    @track referralExists = false;
    @track referralName = '';
    @track referralId = '';

    @track showReferralPhoneField = false;

    @track showSocialMediaPlatforms = false;
    @track socialMediaPlatforms = [];

    @track showProjectFields = false;
    @track showNewProjectModal = false;
    @track showNewFirmModal = false;
    @track projectSearchTerm = '';
    @track firmSearchTerm = '';
    @track projectSearchResults = [];
    @track firmSearchResults = [];
    @track showProjectResults = false;
    @track showFirmResults = false;
    @track newProjectData = { name: '', firmId: '' };
    @track newFirmData = { name: '' };

    @track showPOCFields = false;

    @track duplicateRecordId = null;

    @track _hasRendered = false;

    @track phoneError = '';

    @track country = 'IN';
    @track phone = '';
    
    @track secondaryCountry = 'IN';

    @track panchayatList = [];
    isPanchayatDisabled = true;

    @track showDistrictAndPanchayat = false;

    @track secondaryPhoneError = '';

    @track panchayatSearchTerm = '';
    @track filteredPanchayatOptions = [];
    @track showPanchayatResults = false;

    @wire(getReferenceTypes)
    wiredReferenceTypes({ error, data }) {
        if (data) {
            this.referenceTypes = data;
        } else if (error) {
            console.error('Error fetching reference types:', error);
        }
    }

    @wire(getLeadSources)
    wiredLeadSources({ error, data }) {
        if (data) {
            this.leadSources = data;
        } else if (error) {
            console.error('Error fetching lead sources:', error);
        }
    }

    @wire(getCustomerTypes)
    wiredCustomerTypes({ error, data }) {
        if (data) {
            this.customerTypes = data;
        } else if (error) {
            console.error('Error fetching customer types:', error);
        }
    }

    @wire(getSocialMediaPlatforms)
    wiredSocialMediaPlatforms({ error, data }) {
        if (data) {
            this.socialMediaPlatforms = data;
        } else if (error) {
            console.error('Error fetching social media platforms:', error);
        }
    }

    // Getter for states list
    get statesList() {
        return Object.keys(INDIAN_STATES_CITIES);
    }

    get keralaDistrictsList() {
        return Object.keys(KERALA_PANCHAYATS);
    }

    get panchayatOptions() {
        if (this.customerData.district && KERALA_PANCHAYATS[this.customerData.district]) {
            return KERALA_PANCHAYATS[this.customerData.district];
        }
        return [];
    }

    get toastClass() {
        return `toast-container ${this.toastVariant}`;
    }
    
    get toastIcon() {
        switch(this.toastVariant) {
            case 'success': return '✓';
            case 'error': return '✕';
            case 'warning': return '!';
            case 'info': return 'i';
            default: return '';
        }
    }
    
    get toastStyle() {
        return this.duplicateRecordId ? 'cursor:pointer;' : '';
    }
    
    connectedCallback() {
        // Load executives when component is initialized
        this.loadExecutives();
    }
    
    loadExecutives() {
        getExecutives()
            .then(result => {
                console.log('Raw executives data:', result); // Log raw data
                this.executives = result;
                console.log('Executives loaded:', this.executives);
            })
            .catch(error => {
                console.error('Error loading executives', error);
                this.showErrorToast('Error loading executives', error.message);
            });
    }
    
    renderedCallback() {
        // No third-party library needed
    }
    
    handleInputChange(event) {
        const field = event.target.name;
        let value = event.target.value;
        this.customerData = { ...this.customerData, [field]: value };
    }
    
    handleUpperCaseInput(event) {
        const field = event.target.name;
        const value = event.target.value.toUpperCase();
        this.customerData = { ...this.customerData, [field]: value };
        event.target.value = value; // Update the input field value to uppercase
    }
    
    validateForm() {
        const allInputs = [...this.template.querySelectorAll('input, select')].filter(
            input => input.id !== 'assignedExecutive'
        );
        let isValid = true;
        
        allInputs.forEach(inputField => {
            if (inputField.required && !inputField.value) {
                inputField.classList.add('error');
                isValid = false;
            } else {
                inputField.classList.remove('error');
            }
        });
        
        // Validate required fields
        const requiredFields = {
            'firstName': 'First Name',
            'primaryPhone': 'Phone',
            'state': 'State',
            'customerSource': 'Lead Source',
            'customerEntryDate': 'Customer Entry Date',
            'type': 'Type'
        };

        const missingFields = [];
        for (const [field, label] of Object.entries(requiredFields)) {
            if (!this.customerData[field]) {
                missingFields.push(label);
            }
        }

        if (missingFields.length > 0) {
            this.displayToast('Error', `Required fields missing: ${missingFields.join(', ')}`, 'error');
            return false;
        }
        
        return isValid;
    }
    
    handleSave() {
        if (this.validateForm()) {
            this.isLoading = true;
            
            const saveData = { ...this.customerData };
            console.log('Saving customer data:', saveData);
            console.log('Architect ID before save:', saveData.referenceArchitect);
            
            // Prepend country code to phone numbers
            if (saveData.primaryPhone) {
                saveData.primaryPhone = (COUNTRY_PHONE_RULES[this.country]?.code || '') + saveData.primaryPhone;
            }
            if (saveData.secondaryPhone) {
                saveData.secondaryPhone = (COUNTRY_PHONE_RULES[this.secondaryCountry]?.code || '') + saveData.secondaryPhone;
            }
            
            // Remove empty fields to avoid validation issues
            if (!saveData.assignedExecutive) {
                delete saveData.assignedExecutive;
            }
            // Only delete referenceArchitect if it's completely empty (not just falsy)
            if (!saveData.referenceArchitect || saveData.referenceArchitect === '') {
                delete saveData.referenceArchitect;
            }
            if (!saveData.customerId || saveData.customerId === '') {
                delete saveData.customerId;
            }
            
            console.log('Final save data:', saveData);
            console.log('Architect ID in final save data:', saveData.referenceArchitect);
            
            // Call the Apex method to create the Customer
            createCustomer({ customerData: saveData })
                .then(result => {
                    this.isLoading = false;
                    this.displayToast('Success', 'Customer created successfully!', 'success');
                    
                    // Navigate to the newly created Customer record
                    this.navigateToRecord(result);
                    this.resetForm();
                })
                .catch(error => {
                    this.isLoading = false;
                    let errorMessage = 'Unknown error';
                    let duplicateId = null;
                    if (error.body && error.body.message) {
                        if (error.body.message.startsWith('DUPLICATE_FOUND:')) {
                            duplicateId = error.body.message.split(':')[1];
                            errorMessage = 'Duplicate record found. Click here to view the existing record.';
                        } else {
                            errorMessage = error.body.message;
                        }
                    } else if (error.message) {
                        errorMessage = error.message;
                    }
                    this.displayToast('Error', errorMessage, 'error', duplicateId);
                    console.error('Error creating record:', error);
                });
        }
    }
    
    handleCancel() {
        this.resetForm();
    }
    
    resetForm() {
        this.customerData = {
            salutation: '',
            firstName: '',
            lastName: '',
            company: '',
            primaryPhone: '',
            secondaryPhone: '',
            email: '',
            street: '',
            state: '',
            district: '',
            pinCode: '',
            country: '',
            customerSource: '',
            referenceType: '',
            referenceArchitect: '',
            customerId: '',
            leadType: '',
            leadPurpose: '',
            customerEntryDate: new Date().toISOString().split('T')[0],
            assignedExecutive: '',
            remarks: '',
            referralName: '',
            phoneNumber: '',
            socialMedia: '',
            type: '',
            pocName: '',
            pocContactNo: '',
            pocEmail: '',
            panchayat: '',
        };
        
        this.citiesList = [];
        this.isCityDisabled = true;
        this.isPanchayatDisabled = true;
        
        // Reset all input fields
        this.template.querySelectorAll('input, select').forEach(field => {
            field.value = '';
            field.classList.remove('error');
        });
        
        // Reset search terms
        this.architectSearchTerm = '';
        this.customerSearchTerm = '';
        this.contractorSearchTerm = '';
        this.maisonSearchTerm = '';
        
        // Reset search results
        this.architectSearchResults = [];
        this.customerSearchResults = [];
        this.contractorSearchResults = [];
        this.maisonSearchResults = [];
        
        // Reset display states
        this.showArchitectResults = false;
        this.showCustomerResults = false;
        this.showContractorResults = false;
        this.showMaisonResults = false;
        this.showCustomerReferenceFields = false;
        
        // Reset country selections
        this.country = 'IN';
        this.secondaryCountry = 'IN';
        this.phoneError = '';
        this.secondaryPhoneError = '';
    }
    
    displayToast(title, message, variant, recordId = null) {
        this.toastTitle = title;
        this.toastMessage = message;
        this.toastVariant = variant;
        this.showToast = true;
        this.duplicateRecordId = recordId; // Store for click handler
        
        // Auto hide after 5 seconds
        setTimeout(() => {
            this.closeToast();
        }, 5000);
    }
    
    closeToast() {
        this.showToast = false;
    }
    
    // Add a method to navigate to the record
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Customer__c',
                actionName: 'view'
            }
        });
    }
    
    handleSourceChange(event) {
        const value = event.target.value;
        this.customerData.customerSource = value;
        
        // Reset all reference fields
        this.showReferenceFields = false;
        this.showCustomerFields = false;
        this.showContractorFields = false;
        this.showMaisonFields = false;
        this.showSocialMediaPlatforms = false;
        this.showArchitectFields = false;
        
        // Reset all IDs and values
        this.customerData.referenceArchitect = '';
        this.customerData.customerId = '';
        this.customerData.contractorId = '';
        this.customerData.maisonId = '';
        this.customerData.socialMedia = '';
        this.customerData.referenceType = '';
        
        // Reset search terms
        this.architectSearchTerm = '';
        this.customerSearchTerm = '';
        this.contractorSearchTerm = '';
        this.maisonSearchTerm = '';
        
        if (value === 'Reference') {
            this.showReferenceFields = true;
        } else if (value === 'Social Media') {
            this.showSocialMediaPlatforms = true;
        }
    }

    handleReferenceTypeChange(event) {
        const value = event.target.value;
        this.customerData.referenceType = value;
        
        // Reset fields
        this.showCustomerReferenceFields = false;
        this.showReferralNameInput = false;
        this.showReferralPhoneField = false;
        this.showArchitectFields = false;
        this.customerData.referralName = '';
        this.customerData.phoneNumber = '';
        
        // Show appropriate fields based on selection
        if (value === 'Customer') {
            this.showCustomerReferenceFields = true;
        } else if (value === 'Architect' && this.customerData.customerSource === 'Reference') {
            this.showArchitectFields = true;
        } else if (['Contractor', 'Maison', 'Engineer', 'Plumber'].includes(value)) {
            this.showReferralPhoneField = true;
        }
    }

    handleReferralPhoneChange(event) {
        const phoneNumber = event.target.value;
        this.customerData.phoneNumber = phoneNumber;
        
        if (phoneNumber && phoneNumber.length >= 10) {
            checkReferralExists({ 
                phoneNumber: phoneNumber,
                referenceType: this.customerData.referenceType 
            })
                .then(result => {
                    this.referralExists = result.exists;
                    if (result.exists) {
                        this.referralName = result.name;
                        this.referralId = result.id;
                        this.showReferralNameInput = false;
                        this.displayToast('Info', `Existing ${this.customerData.referenceType} found: ${result.name}`, 'info');
                    } else {
                        this.showReferralNameInput = true;
                        this.displayToast('Info', `Please enter ${this.customerData.referenceType} name`, 'info');
                    }
                })
                .catch(error => {
                    console.error('Error checking referral:', error);
                    this.displayToast('Error', 'Error checking referral', 'error');
                });
        }
    }

    handleArchitectSearch(event) {
        const searchTerm = event.target.value;
        this.architectSearchTerm = searchTerm;
        
        if (searchTerm.length >= 2) {
            searchArchitects({ searchTerm: searchTerm })
                .then(results => {
                    this.architectSearchResults = results;
                    this.showArchitectResults = true;
                    this.showAddNewOption = true;
                })
                .catch(error => {
                    console.error('Error searching architects:', error);
                    this.displayToast('Error', 'Failed to search architects', 'error');
                });
        } else {
            this.showArchitectResults = false;
            this.showAddNewOption = false;
        }
    }

    selectArchitect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.architectSearchResults.find(arch => arch.Id === selectedId);
        if (selected) {
            console.log('Architect selected:', selected);
            this.architectSearchTerm = selected.Name;
            this.customerData.referenceArchitect = selected.Id;
            console.log('Architect ID set in customerData:', this.customerData.referenceArchitect);
            this.showArchitectResults = false;
        }
    }

    handleAddNewClick() {
        console.log('handleAddNewClick called');
        this.newArchitectData = {
            name: this.architectSearchTerm,
            phoneNumber: ''
        };
        this.showNewArchitectModal = true;
        this.showArchitectResults = false;
        console.log('Modal should be visible:', this.showNewArchitectModal);
    }

    handleNewArchitectInput(event) {
        const field = event.target.name;
        this.newArchitectData[field] = event.target.value;
        console.log('Architect input changed:', field, event.target.value);
    }

    createNewArchitect() {
        console.log('createNewArchitect called');
        console.log('newArchitectData:', this.newArchitectData);
        
        if (!this.newArchitectData.name) {
            this.displayToast('Error', 'Please enter Architect Name', 'error');
            return;
        }

        this.isLoading = true;
        console.log('Calling createArchitect with:', this.newArchitectData);
        
        createArchitect({ 
            name: this.newArchitectData.name,
            phoneNumber: this.newArchitectData.phoneNumber || ''
        })
            .then(result => {
                console.log('Architect created successfully:', result);
                // Set the architect ID in customer data
                this.customerData.referenceArchitect = result.Id;
                console.log('Architect ID set in customerData after creation:', this.customerData.referenceArchitect);
                // Set the search term to show the selected architect
                this.architectSearchTerm = result.Name;
                // Hide the search results
                this.showArchitectResults = false;
                // Close the modal
                this.closeNewArchitectModal();
                this.displayToast('Success', 'Architect created and linked successfully', 'success');
            })
            .catch(error => {
                console.error('Error creating architect:', error);
                let errorMessage = 'Failed to create architect';
                if (error.body && error.body.message) {
                    errorMessage += ': ' + error.body.message;
                } else if (error.message) {
                    errorMessage += ': ' + error.message;
                } else if (error.detail) {
                    errorMessage += ': ' + error.detail;
                }
                this.displayToast('Error', errorMessage, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeNewArchitectModal() {
        this.showNewArchitectModal = false;
        this.newArchitectData = { name: '', phoneNumber: '' };
    }

    // Customer search handling
    handleCustomerSearch(event) {
        const searchTerm = event.target.value;
        this.customerSearchTerm = searchTerm;
        
        // Reset results and states
        this.showCustomerResults = false;
        this.noCustomerResults = false;
        this.customerSearchResults = [];
        
        if (searchTerm.length >= 2) {
            this.isLoading = true;
            searchCustomers({ searchTerm: searchTerm })
                .then(results => {
                    this.customerSearchResults = results || [];
                    this.showCustomerResults = true;
                    this.noCustomerResults = !results || results.length === 0;
                    console.log('Search results:', results);
                })
                .catch(error => {
                    console.error('Error searching customers:', error);
                    this.displayToast('Error', 'Failed to search customers', 'error');
                    this.noCustomerResults = true;
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    selectCustomer(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.customerSearchResults.find(cust => cust.Id === selectedId);
        if (selected) {
            this.customerSearchTerm = `${selected.Name} - ${selected.Company}`;
            this.customerData.customerId = selected.Id;
            this.showCustomerResults = false;
        }
    }

    // Contractor handling
    handleContractorSearch(event) {
        const searchTerm = event.target.value;
        this.contractorSearchTerm = searchTerm;
        
        if (searchTerm.length >= 2) {
            searchContractors({ searchTerm: searchTerm })
                .then(results => {
                    this.contractorSearchResults = results;
                    this.showContractorResults = true;
                })
                .catch(error => {
                    console.error('Error searching contractors:', error);
                    this.displayToast('Error', 'Failed to search contractors', 'error');
                });
        } else {
            this.showContractorResults = false;
        }
    }

    selectContractor(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.contractorSearchResults.find(cont => cont.Id === selectedId);
        if (selected) {
            this.contractorSearchTerm = selected.Name;
            this.customerData.contractorId = selected.Id;
            this.showContractorResults = false;
        }
    }

    handleAddNewContractorClick() {
        this.newContractorData = {
            name: this.contractorSearchTerm
        };
        this.showNewContractorModal = true;
        this.showContractorResults = false;
    }

    handleNewContractorInput(event) {
        this.newContractorData.name = event.target.value;
    }

    createNewContractor() {
        if (!this.newContractorData.name) {
            this.displayToast('Error', 'Please enter Contractor Name', 'error');
            return;
        }

        this.isLoading = true;
        createContractor({ name: this.newContractorData.name })
            .then(result => {
                this.customerData.contractorId = result.Id;
                this.closeNewContractorModal();
                this.displayToast('Success', 'Contractor created successfully', 'success');
            })
            .catch(error => {
                this.displayToast('Error', 'Failed to create contractor: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeNewContractorModal() {
        this.showNewContractorModal = false;
        this.newContractorData = { name: '' };
    }

    // Maison handling
    handleMaisonSearch(event) {
        const searchTerm = event.target.value;
        this.maisonSearchTerm = searchTerm;
        
        if (searchTerm.length >= 2) {
            searchMaisons({ searchTerm: searchTerm })
                .then(results => {
                    this.maisonSearchResults = results;
                    this.showMaisonResults = true;
                })
                .catch(error => {
                    console.error('Error searching maisons:', error);
                    this.displayToast('Error', 'Failed to search maisons', 'error');
                });
        } else {
            this.showMaisonResults = false;
        }
    }

    selectMaison(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.maisonSearchResults.find(mais => mais.Id === selectedId);
        if (selected) {
            this.maisonSearchTerm = selected.Name;
            this.customerData.maisonId = selected.Id;
            this.showMaisonResults = false;
        }
    }

    handleAddNewMaisonClick() {
        this.newMaisonData = {
            name: this.maisonSearchTerm,
            company: ''
        };
        this.showNewMaisonModal = true;
        this.showMaisonResults = false;
    }

    handleNewMaisonInput(event) {
        this.newMaisonData.name = event.target.value;
    }

    createNewMaison() {
        if (!this.newMaisonData.name) {
            this.displayToast('Error', 'Please enter Maison Name', 'error');
            return;
        }

        this.isLoading = true;
        createMaison({ name: this.newMaisonData.name })
            .then(result => {
                this.customerData.maisonId = result.Id;
                this.closeNewMaisonModal();
                this.displayToast('Success', 'Maison created successfully', 'success');
            })
            .catch(error => {
                this.displayToast('Error', 'Failed to create maison: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    closeNewMaisonModal() {
        this.showNewMaisonModal = false;
        this.newMaisonData = { name: '' };
    }

    // Add this new method to handle state change
    handleStateChange(event) {
        const selectedState = event.target.value;
        this.customerData.state = STATE_CODES[selectedState] || selectedState;
        this.customerData.panchayat = '';
        if (selectedState === 'Kerala') {
            this.showDistrictAndPanchayat = true;
            this.isPanchayatDisabled = true;
        } else {
            this.showDistrictAndPanchayat = false;
            this.panchayatList = [];
            this.isPanchayatDisabled = true;
        }
    }

    handleDistrictChange(event) {
        const selectedDistrict = event.target.value;
        this.customerData.district = selectedDistrict;
        this.customerData.panchayat = '';
        this.panchayatSearchTerm = '';
        this.filteredPanchayatOptions = [];
        this.showPanchayatResults = false;
        if (selectedDistrict && KERALA_PANCHAYATS[selectedDistrict]) {
            this.panchayatList = KERALA_PANCHAYATS[selectedDistrict].map(p => ({ label: p, value: p }));
            this.isPanchayatDisabled = false;
        } else {
            this.panchayatList = [];
            this.isPanchayatDisabled = true;
        }
    }

    handlePanchayatChange(event) {
        this.customerData.panchayat = event.target.value;
    }

    handleReferredPhoneChange(event) {
        const phoneNumber = event.target.value;
        this.customerData.phoneNumber = phoneNumber;
        
        if (phoneNumber && phoneNumber.length >= 10) {
            checkReferredCustomer({ phoneNumber: phoneNumber })
                .then(result => {
                    this.referredCustomerExists = result.exists;
                    if (result.exists) {
                        this.referredCustomerName = result.customerName;
                        this.showReferralNameInput = false;
                        this.displayToast('Info', `Existing customer found: ${result.customerName}`, 'info');
                    } else {
                        this.showReferralNameInput = true;
                        this.displayToast('Info', 'Please enter referral name', 'info');
                    }
                })
                .catch(error => {
                    console.error('Error checking referred customer:', error);
                    this.displayToast('Error', 'Error checking referred customer', 'error');
                });
        }
    }

    handleReferralNameChange(event) {
        const value = event.target.value.toUpperCase();
        this.customerData.referralName = value;
        event.target.value = value; // Update the input field value to uppercase
    }

    handleSocialMediaChange(event) {
        const platform = event.target.value;
        this.customerData.socialMedia = platform;
    }

    handleTypeChange(event) {
        const value = event.target.value;
        this.customerData.type = value;
        this.showPOCFields = value === 'Project';
    }

    handleToastClick() {
        if (this.duplicateRecordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.duplicateRecordId,
                    objectApiName: 'Customer__c',
                    actionName: 'view'
                }
            });
        }
    }

    handlePhoneInput(event) {
        const digits = event.target.value.replace(/[^0-9]/g, ''); // Only digits
        this.customerData.primaryPhone = digits; // Update the tracked field
        const rules = COUNTRY_PHONE_RULES[this.country];
        if (digits.length < rules.min) {
            this.phoneError = `Number is too short for ${rules.name} (${rules.min} digits required)`;
        } else if (digits.length > rules.max) {
            this.phoneError = `Number is too long for ${rules.name} (${rules.max} digits allowed)`;
        } else {
            this.phoneError = '';
        }
    }

    handleSecondaryPhoneInput(event) {
        const digits = event.target.value.replace(/[^0-9]/g, ''); // Only digits
        this.customerData.secondaryPhone = digits; // Update the tracked field
        const rules = COUNTRY_PHONE_RULES[this.secondaryCountry];
        if (digits.length < rules.min) {
            this.secondaryPhoneError = `Number is too short for ${rules.name} (${rules.min} digits required)`;
        } else if (digits.length > rules.max) {
            this.secondaryPhoneError = `Number is too long for ${rules.name} (${rules.max} digits allowed)`;
        } else {
            this.secondaryPhoneError = '';
        }
    }

    get countryList() {
        return Object.entries(COUNTRY_PHONE_RULES).map(([code, data]) => ({
            code,
            name: data.name
        }));
    }

    handleCountryChange(event) {
        this.country = event.target.value;
        this.phoneError = '';
        this.phone = '';
    }

    get selectedCountryCode() {
        return COUNTRY_PHONE_RULES[this.country]?.code || '';
    }

    get selectedSecondaryCountryCode() {
        return COUNTRY_PHONE_RULES[this.secondaryCountry]?.code || '';
    }

    handleSecondaryCountryChange(event) {
        this.secondaryCountry = event.target.value;
        this.secondaryPhoneError = '';
        this.customerData.secondaryPhone = '';
    }

    handlePanchayatSearch(event) {
        this.panchayatSearchTerm = event.target.value;
        const allOptions = this.panchayatOptions;
        if (this.panchayatSearchTerm && allOptions.length > 0) {
            const search = this.panchayatSearchTerm.toLowerCase();
            this.filteredPanchayatOptions = allOptions.filter(p =>
                p.toLowerCase().includes(search)
            );
            this.showPanchayatResults = this.filteredPanchayatOptions.length > 0;
        } else {
            this.filteredPanchayatOptions = [];
            this.showPanchayatResults = false;
        }
        this.customerData.panchayat = this.panchayatSearchTerm;
    }

    selectPanchayat(event) {
        const value = event.currentTarget.dataset.value;
        this.panchayatSearchTerm = value;
        this.customerData.panchayat = value;
        this.showPanchayatResults = false;
    }
}