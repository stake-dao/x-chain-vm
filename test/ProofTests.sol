// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import { console2 } from "forge-std/console2.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { EthereumStateSender } from "src/EthereumStateSender.sol";
import { CurveGaugeVoteOracle } from "src/CurveGaugeVoteOracle.sol";

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract ProofTests is PRBTest, StdCheats {
    address user = address(0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6);
    address gauge = address(0xd8b712d29381748dB89c36BCa0138d7c75866ddF);
    uint256 time = 1669248000;
    uint256 blockNumber = 16041523;
    bytes32 blockHash = bytes32(hex"b327dd4a5e2962e70376078a721bec307ea254b1e790f4851e672d22b5fd6722");
    EthereumStateSender sender;
    CurveGaugeVoteOracle oracle;

    function setUp() public {
        // solhint-disable-previous-line no-empty-blocks
        sender = new EthereumStateSender();
        oracle = new CurveGaugeVoteOracle();
    }

    /// @dev Run Forge with `-vvvv` to see console logs.
    function testExample() public {
        uint256 lastUserVote = uint256(keccak256(abi.encode(keccak256(abi.encode(11, user)), gauge)));

        uint256 pointsWeight = uint256(
            keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, gauge)), time))))
        );

        uint256 voteUserSlopes = uint256(
            keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, user)), gauge))))
        );

        (address user_, address gauge_, uint256 time_, uint256[6] memory positions, uint256 blockNumber) = sender
            .generateEthProofParams(user, gauge, time);
        // console2.log(positions[0]);
        // console2.log(positions[1]);
        // console2.log(positions[2]);
        // console2.log(positions[3]);
        // console2.log(positions[4]);
        // console2.log(positions[5]);
    }

    function testHash() public {
        oracle.setBlockHash(blockNumber, blockHash);

        bytes memory rlpProof = bytes(
            hex"f93cd9f90e47f90211a0661a2034c8513b6692f39981c8f24d481da72fa6d669994266d956ad22c712d2a06dd0bc2382b98a5c29452df194bab9b6d9a1e445b6df608e3921d213ec7a12d2a0a5ab2314dc69e7240f53932d395fe8acac184bcc3cf8d86c5434872d39c619b9a0fd1385b3fd6f3a7d594c4950f3f62b19647e105fb2992c0f2ba5d3ae7773aa48a0a40e0cf0c78745910ffd70c4e0fba841c76e0927ada14932925f18fed7197f2ca035c9014af49548b4af149c0337bf4c1d0126b77643198efd08f3b12b4ca0e6dca0a3ecc365f1213f159ea11c4419b5c9c6ab2229c17fafda216e7b38c5a0c7d944a0f836ff9271652f6bf8c90abe734a58dbca8d24f4adb7bf6a8b117a6de464bc09a050cc0f1cfcace439a9812b640b39a00619c3aaa3f518c2948c8773997eb5a13ba014b26c580f9c14757af9fd7859f62839a703663219623faddf3930615585a0fda0debf191f025dddc75b4b928ca2fa3398afca73ac86c48484454ef1beb476be95a074c454e8dc5b72b7703350d0298f21fc8e65bbcf2466148e3fc1eda40cccb099a0d440e4600b481078dc051b3421d07773210d90b2198b0f25588f98e9574ded37a0429c64e94c1d4a0712a9203d63ee0809b4348a8d85c968530edf4baa7730a181a0701a7d3067f325dbcb5b27eda3f2043af8a280ea676d362cb28174c711c10b9aa05d355dcefb5cf44ffd0a7aaea8fe828fb4bc4259402f635d677062f38878fe1080f90211a015188680d157395632373fce2c24feb3e70ca70443853b5fbbd6d02c73f0ab12a058d9d83b712f21757f2c496c27d089edd291c1e5b84ed79d49f23856aca347d0a08688fbf7317bc4ff287f13a62aed03b120f1bc8c930abf92d392d2b4b66f9b7fa0b21103b7910a52a577e0e53a46b56ab9e0c82345eccdae66e991c04dc0a15ee8a00907e1a603f3364573d22e51d33e1c8d845b65ce87f2b0d9c81bf5f66d9aacfca0c60ee843b1261a5e77bea2386bc60ddb8d0e9b92a4c9b9fe305613fb5944d791a08be26fdfb04cf3b37f46fa5b03c3a0daffb333f5ffefe46fbaa870bd1684616da0e6fef6b36f2b76f34058f581c1209fc119cd4d8643abb0a3dd6fc15dcc825675a0cd56e853c06534384422b27b974fed9f7684bcaf78224d6920fe6190d333cffba03ee71f0c4df5b9f983af6994a353a69b7b4998484d10729c28bdb16cc8b65188a07b8b6a103e97ba3ca992cb8a2165179a3b537a223ba3dc8005e383f6d3c30a56a089e9878292a24925fb40a0e3be84d7728067f875e58e5c9436267fba93ba029aa0902a51d21088fb2560719b955da761b35b40ae592eb0df554a8c3b30cd866a53a0ad9ab468b81a429ff6ead949258f27833b538a2736c72c8fd88ecec7555df024a0c531a066b9e106a04f7462fefe79be3fc7419fa413f72325fc81ab0299f01b22a0c783688ba89934d93c56f0eae288662cb81d50a58557bb102c9db41af83cfb7480f90211a0bd4828f595b5fdd647402843c26ed979458dec17f25989ae610419b5923e6ff8a0ebf4e8deecfe8620b7b313fd411c7d1d3beb755d017fda7391dc826ffd98a665a02358be5392bb09509285ec7505b99996e9e24eeb2a1b1073e2b78898aee0823ba05f0508a13e79e585ae255f768e49f2327c33f8fe02a1ab819c47f7d17db8deeba03fcb46e5bc6be68e07bb7743dc9ed01f038d9e79c2c123f0bae05ef01368cdcda02df6bd64e5468e23f4accccb8fc8f23d6d79601906dd1e8cc1943a62bdaabffca0f0b3ccd3b24bcd7c8577e48e49c10902da7b4f25e19f1d36c9299ae23ea5a630a0a0a581dacfc8b13268eadfffd5dce30a2cb089a6b1e8dfb0a2702e407d099f67a0068c55df85fabd5ff5433dc14dacf6585dc99c131731eb19905ee22e1aa2f643a0c46d46013ef6fdf5510d8ac72c9338fb5cf98d6a475e82a568fb6689158d5f7fa014c2c86f79e8c07630e80ae60e23c7e7f7edf18799f6afc1aa30145cbbd22a9da060e4e23a58f72a1351dc7e0b45a2c4e3ad42aef0290342c60f6f3f4c53629bb2a047546a82c99b18749e7a003681a599d6f4e0f99c242fd56abfa0dd44f040e8fda0b47dfb85e6e0ce87f581c8bafa0121d801867a1da978a0ae95452b8b5045d6b8a0775a0249b3408781734735e2acfdf4f5013e8efcb2f72511428e3ee4243ccfa9a0aa5667e72d03e0578580b9a5341ae76ecc9ae6bae9ca06f1f850d35b685efaf080f90211a0d09be7470d88a96ddd02fc95ce67a176436c6317bc8f432417ba1603edf71944a096db229d490cc5960d41250bb7d90964fde599c4921d5c93e1e46f75dfefc429a078b04efcf81ebcfff43d6250260ed8c06e43083a0c7d268169cc0463c4d63733a0318be7ca04bf7c12f60dccfb8dc6b9de6c3c9cbce25b30f12d005ed4ce889631a0d649255d4453e32b85578c709c20a5c694f354031f2965a3da8d3646e17c290ba06c0f16a6fbad4cc5a52622f9724ee65bd2fffd657cfbf11d4698ada73d1fccfda001961d3c504bf04213941155081d6eba0d57c6af26e83fa4b605c9870f1a55cca0841283753a3a24240e93a86d32cfd4ebd0a423c7ecb8866ecfb8615a5e88786ba02878d9149bc6bf75b6ebaa83226c3902a33ed4f82ba342dca785dd0e98bee333a0ed35d0c01eb16d3a962e753312636ad6fde6c5b5f4f677f577ea8bae64e74a71a047cfcaea3999b39635d5719a4f405009435c277f7c18357ea18b087c93adba03a0eb7be47d582a4f501b8d64d425c03fc4877b9b9fa06163e374b34ee4e75e5d91a001c916e267f09328eb1002499d70120310fb733483f5fa8bf711860ca194548ea07a07e2351621afb7c09d573a4b675c9b0c30f3be45dfa6fb74e7865c9530cb58a0fc8d131510b403d893e9b5f758e9779ae82fb929cb806ee6e3c0caf54964c836a08f0a12fdfa60059756a2b1e516036ed9f9b105de330ba0377f496160b77adb3680f90211a0e27bfd1970a861f47448e8c9dab942f811dacf3e9c58405b419417e7fdea8714a03a81a1962dc1b66e91245bf9e418b337cb5ff00a32b61566d799e5e66e320f20a0358691a45a32b39f44e7d61fc9775b7e2a6bb5cc3102403d13f706f6553e81dfa0cc737499f31dc6aa7c33909a9f3d5acd892a564159eb7f519a9269126d64c3a3a00927607d8c0bb49a9a6c050eb7cb0926dbc6097cbe08644febc03a4e2f209ffea08354a04aeae7bd0f241d30ac6ec7842b546376e577dca84aea5325c1cf140fd3a077816bdc7d699ab68d5ee0f71544fb2104f6632db2dd3466756e4165d3f80fada09c5b931ce661afd7a51abc5abb9f990bd5236c6569b73f1d355997f4161ddd2aa02ab0f703ec34ac55ba05e07543c7afc86e685686a898b095cfa122f19fe38548a0845363e3f98353b945032e4aa9007dbac94d42496e53e5f94c50711812244668a0065f5431c071e5b44211e276a72df61b6bc3f8981489a8808195f4b12c66289ba0854b15945bd6ad9c37222e7d12847e9f68859717cf4d2838eb61232449f0ab32a0fdc8959b2a3e9cd35f382699b30fbba4a52809066d2373bbeef11362ae58c20fa0bbb2d070d274440735592efc8a7035b643c04063d545051f934a3093c2d2ce9fa061cfe2b738061bcdfcf7e2a5b0a0f4ba604324eb213440f883cccc58acb3095ea0603287aa9be93721c376d469d931bb9f5163a735bf2fbfcbc9f8e37a27d2e28d80f90211a077cea0724493fc1f0277bd5fa9507ae1156af8af9e434d852aa3028a342f6712a01e46f0c71142583d9849fb09166d56ab260ff43f851937262565efcf9a5cf329a0f5f78eba51887e8aed905ed9ace61679dbe68fdc0ae516209d36ab860816f771a03b775ec8933deef779148c13309e6af8736dbf82432279d1df0350993af7978ba02523b83c1094bfb802c4232bae4b06acc021d6255c7bc4070623d6d09dd702cca0d5ceeb2084f278b10b3e52ea92ea76125db14360559655789d5f0110a1ffeb78a0bcd87c4cf9c58ab5053fa046e88bde302e25682b50aa724b4ff7e7de076eba42a077eb3d069838e8996aeb92c4c16e824d283ad885e22a611c61a81f2a4e1cc748a0b6a4424e8158ea6df3dc4430349c4f3a6f888365ed06b98eb53a768af95badd5a03a2606981aa597e3b41ddb825d73be7d9de5c4ad11844b69edfd85df399ebfc2a0976fcb39a27e289d2a43873a66e82ca2fba8032f522616bed0525e22667b6e7fa0935e0d29957ffc28e83962fbc925c950bb2527ab6e5d24904199896d5bd52475a0d05fb99c54b9c52c3ef48feb0f41df210d804d1737ad67b38bb84c47d6ffc483a01d04581d0922471738ee900e34ed7a49827e030fedb44858767fecbfc934b64ea02726a1d9f7c646f8dfc397eb82832da6f4fcf877a0817e4a027f52205ed38cf5a00d7dc3f29d8bed12352caa01abdc216c3a6f9dca2b9e2d2ac6998176a9f0236c80f901118080a0c04ecc6ad57490bd0bebebde18a81dbb6d05bb90ae63d79bb5e68030d91e569980a0f1d2aa4db07bedfe0f0149afade7a31bdeac77397fef95f0017e0973c3965b7980a0e89d9895b6f36966fe9f8ec28707900aedeaf2c7e0ce02395f8c5b975bd36949a09f8e2ee438ed090ba1ef20217617e5f87220383a485438bfbdf76699bf080ca4a00bdb2f3d8c81de151c28a001ad2c765f1a4e38318fe717f32389394e799d8879a0e67ecf68abcdee8cf7e2eb2a68357d81242344db3a373540a3b2e13b9a07f230a07259ea895d12daa67a1674487ae7edcbd4270c8e8fe402eb93334b09f2682bd58080a0e1768f462462ef1625eefede5d3cb80a5592eef7bc9a815f36f24ca6bbfe82d4808080f8518080a0d7c84023deb040b4650fe72495c709059940bab0fbe008247f88df0bbd5bc7598080808080808080808080a0889327722d3675800d695f7a6d82ff0d4caedc7dfc565b30431bd1595df415138080f8669d2051d27564f387adf7af9e9a5a8195d11b3334b010b8a70766e9dcc32bb846f8440180a0c33025326afb82d7647b9278bca5b3b447fba6cc9dbbe40d2cf70616736d44aca0655bec9519bc4e87c56bb2c54767c5ae6407f8be1b29140f5110c29d9607d42df90788f90211a01a40054ef17103331c164c398c66bf67c9115a454f12c8439f42e4d68569895ba096d0ac8c323242a6023a1f5711a6e33ad40965728f899dd40cf1ba315a50ebcaa088406e397909aa73061db5d232bd591d1be52ad8322579d1a68ef5781f69f721a050012d876070374f3fd88cf2ec41ba5956a931bf7d151921a83302e8c2f948e5a00370a6e8f18bbd181864781a00aa7ec32de94a9edf81dbe7b9094b939ed45e1ba0e37ef99884cf7da1502d183e4e8119a9be58640206b8dd72e4658bc0515c5411a05484afb2665f95e283790cb9b386e9cdc988d4a0baa99623664fed2c022c814ba046eb3cd2fdd93e7b7e0385bac3595f430512e0be589d4b9dc2fc05c329f55681a0f41d9419697ab21c9958b70b328119f88ffe086cfc65dc64f83fc4b66ffa0815a0d76377249b30d75cb05718632695eff04f9ede1634f0fe1085959e4281652bd2a057266a618f533455590cb5ce0e289d185f8712e914249fae44eacaea7366a426a0edc3e781db9937cab57457482a9d1ca2e485c3296233037a80948171e089057ca0e619b0f8a118d50c20ecc0d7b592f16e335a19709ac263ff5f06c2ea214fe3a3a034b1065f37f103ce6465982babf6c498c17dcf1c0291f302ebe823f988534effa03cc27cc12bb6620a714ca3ac64eb86148eb912ef1cd0525ef032ff487edf9653a074dad14093bbcbf25bcf0832f952d35d935b72ee780e9aab51308c053485568c80f90211a02db0f3b8c7178b1dcdd38b13dd5b795a1dbbe220d0c4a0a7f72ebd1bf90c1088a0391a6ce612e61dacfc254d5b7c02d70c9be9d16d4987e6c749cd41d35aae148ea0c16ee8200cea802ed4722f195df9f9d48b8d3e95896402459f4a24d1bbab170aa059ead56fd677105c87fa8cc7e55ae9ac18973b1b61fcdf520ada43fb8ef8ff08a0f65ea43664cbfe8f7dd70f5bf61f2c27ef19418a7517d7b1100535458993f5b6a05a9e6ffb82ecf14ed559cf7567faac1b65d08ae5500a4cfe81f700aacefcbac3a0181efdaf559a620680041f62b6adfae74aff90e1226611ee256edb4bbd53ebada0ce957daf428816945f428e627e28c15a1dab58a1e098dbfe6fb8809c7af2c3c4a03786d97af45f12ee6370178cc8a2745efcb4cdb741f101e45d4e3ee3ffd2419aa001ef56eac27cd5a724ad9559a2e1cc6a209089948b97542da18987a7f4db2cd3a06f4b8e545dc9bfd18ebb511b7e40110d68d1a397ac26110e03ca696d435f79faa04855ff6825b2d54311cffdb363701ab4fd5dead698245fdfa83fd054ca42dd3aa098d45aa4d3b5450b5431862c8654099a97e738f748a5e1e3af5fd15c97ea69c8a0a1e0cc2c603cf25a68f2c5e1f1ca1b2c93d6a690dd577e59607ce29aefa533a1a0666c3d5571dcbc6ff6cbc6aed64d7185d707d513dd047b066f96feeafaa99576a0ecd8dc9fb70eb60774885d9c37120bff66fdfb497853df52388a8b4457f9328a80f90211a06eccc623ee40aa6ca216c570c324502864fd0ed62d01655d00890424125cbc77a0d4142388a6259062e5c7254b96a85c3e942ed28ce7ce12135c6dd4d7213f0fbca0923dcea3d3135aeea9c20aef3e8eaaa00cd14b7eeb8da9a1c9b260567bc32cdea0325cea0a865d18b33ee9afa308f1e13a8340fb76369da54cea7108181afd93c1a062ee2f85c9a660de312c9f1689a847903a5ccbabd0b7c1f56e219eb50147e9aba0ae9092f34b2c40458b21f9cf0755807b35c695d1d89fde66af7741bcf1856976a090013bd5247b7f07154642522916b8d3093102736608607ac7be052eb085a9fea0aa7806992d765d74bb44388520f09d64ffe1b59f21c6c6ecb786238d93871d13a0876bc68ab839c57fd5e4ac314d5f5042b5a4ceca7371ec3f00776dfc3207dcb3a0e96dea6d271d56747e8eef342381fd7d020381b2f81a4a05d453e0d6c4183013a0a96ab2a93edb16317b32ee04524c672cafa2c7d2bde963e25f6d5e98794de1daa00fc6445fc415bee3f8ed890d2e5db92bee4fe4b546c8b5987614b5e3ccfcc60aa0632735512d83c19c6f703b2c173850711f88d96ae242f9a21564ef41ec161cc6a03a99cca4b06cfa6b3ff513806a47f48aa34684d4a4b21e9c2dc9e6a1cb2a4d26a07fe281dc6b6b77a9899b063d41932e8e066f741956411770f4ab63031b441127a0f88d9229a725662dbbfaa3ad060ad9d7092a870827a38e5ec18073f762b9c7bc80f8d18080a00c4e9b603423e9a7562bbb981497d4d89d76e0a3eda23a7811dd89a7650e0e6080a0e64a41e3c7595f0a35e8c5d3ad229478465864c3216c6a1c1c7001476418341e80808080a06dd5d259168dbf7c9bbcddaa689a27b3f3c827ee1b175363314b8218c5e63bdea0374dc431f4725ba91ecebfa374de4f3fe930ea970119276abb31d59171e9f92aa0da9a6d8bfee6ac5dfcd3840a834f892da3550b322d6915213cc1fa5981343ead8080a056eee578e72bd6ff9551595c72e145dcc0a83f4633453a5ba61f95421a7168b18080f8518080808080808080a0a94cf1d67f6147d51d539439b94ad7e8e80113be9a92399fd718c02d6c00fa3f80a019fb1c0e78cb3bde82427aed684f39bee3cad6676ad2a47182ca54732e50316a808080808080e59e3dc4b28ed8bf3331b1076207115e4b9b398b119fc276f391c9f0c12b386e858463739ea7f90810f90211a01a40054ef17103331c164c398c66bf67c9115a454f12c8439f42e4d68569895ba096d0ac8c323242a6023a1f5711a6e33ad40965728f899dd40cf1ba315a50ebcaa088406e397909aa73061db5d232bd591d1be52ad8322579d1a68ef5781f69f721a050012d876070374f3fd88cf2ec41ba5956a931bf7d151921a83302e8c2f948e5a00370a6e8f18bbd181864781a00aa7ec32de94a9edf81dbe7b9094b939ed45e1ba0e37ef99884cf7da1502d183e4e8119a9be58640206b8dd72e4658bc0515c5411a05484afb2665f95e283790cb9b386e9cdc988d4a0baa99623664fed2c022c814ba046eb3cd2fdd93e7b7e0385bac3595f430512e0be589d4b9dc2fc05c329f55681a0f41d9419697ab21c9958b70b328119f88ffe086cfc65dc64f83fc4b66ffa0815a0d76377249b30d75cb05718632695eff04f9ede1634f0fe1085959e4281652bd2a057266a618f533455590cb5ce0e289d185f8712e914249fae44eacaea7366a426a0edc3e781db9937cab57457482a9d1ca2e485c3296233037a80948171e089057ca0e619b0f8a118d50c20ecc0d7b592f16e335a19709ac263ff5f06c2ea214fe3a3a034b1065f37f103ce6465982babf6c498c17dcf1c0291f302ebe823f988534effa03cc27cc12bb6620a714ca3ac64eb86148eb912ef1cd0525ef032ff487edf9653a074dad14093bbcbf25bcf0832f952d35d935b72ee780e9aab51308c053485568c80f90211a02db0f3b8c7178b1dcdd38b13dd5b795a1dbbe220d0c4a0a7f72ebd1bf90c1088a0391a6ce612e61dacfc254d5b7c02d70c9be9d16d4987e6c749cd41d35aae148ea0c16ee8200cea802ed4722f195df9f9d48b8d3e95896402459f4a24d1bbab170aa059ead56fd677105c87fa8cc7e55ae9ac18973b1b61fcdf520ada43fb8ef8ff08a0f65ea43664cbfe8f7dd70f5bf61f2c27ef19418a7517d7b1100535458993f5b6a05a9e6ffb82ecf14ed559cf7567faac1b65d08ae5500a4cfe81f700aacefcbac3a0181efdaf559a620680041f62b6adfae74aff90e1226611ee256edb4bbd53ebada0ce957daf428816945f428e627e28c15a1dab58a1e098dbfe6fb8809c7af2c3c4a03786d97af45f12ee6370178cc8a2745efcb4cdb741f101e45d4e3ee3ffd2419aa001ef56eac27cd5a724ad9559a2e1cc6a209089948b97542da18987a7f4db2cd3a06f4b8e545dc9bfd18ebb511b7e40110d68d1a397ac26110e03ca696d435f79faa04855ff6825b2d54311cffdb363701ab4fd5dead698245fdfa83fd054ca42dd3aa098d45aa4d3b5450b5431862c8654099a97e738f748a5e1e3af5fd15c97ea69c8a0a1e0cc2c603cf25a68f2c5e1f1ca1b2c93d6a690dd577e59607ce29aefa533a1a0666c3d5571dcbc6ff6cbc6aed64d7185d707d513dd047b066f96feeafaa99576a0ecd8dc9fb70eb60774885d9c37120bff66fdfb497853df52388a8b4457f9328a80f90211a0ccb9ad2d8731ae38792eac11d45509a02f68a3fb59bf68f96d28d24887461c40a0c9dfdb05f18cb2a9dd40ab3b8fbe364305b7e4e1e7e80d766b4c64421035ef9ea0d63a784fdc26a4288f7a374a0edc2edff1c6a7dd277d6e3217c99fc54d892dd1a042855a58e2b8f5f908e45deb4ec7e6f6899f51e723b1c89857679f218afdbfd9a0daf38693606d38ceee077ab34a9f15390ec8e84115c62da4bbc6d2aca2a0a40ca0748903c766d24b00c1a339ab8cce45d97fa6c67d3fb8e524de4690b5e778657ea0b3e68ee66fcd72f4bf28f13dc26048158c5cf1e491151b3ca2b1f1d1d04477a2a08d86ce570d7c8c6f90dbb8f584f55de9b1b1540f00f12abf8e1a574c6b995e70a0a7e4fb693e12bf5072746f436759fc854398aff04c0210b5168d63d4aeaae604a01ae28e8425a29be6b2f53c0b6e93261a4ea50d6c068df57b3f1b85cc0a1da96ba0868bf0e46387878cd3c1c178a0c8759726ab3c366bf30e7f2d0cfc1ea54e7765a04dcaed9cd2d9008096135c36460934715e37d8834b6ab82d215665021c379ce4a0bbb8a7a1feca8da8454fbe7dbb9192ab942c1786d5872e24c54135bb393177f2a00722831add92535eda1b6efe24b00b2b320ec9f76946248e46dd898fd77170d6a04ae7080a4d3f050f8e4b871bc2fca5ef6465cdb28404b539e3e345739586c96fa04be1c93cd4fa9fff345b23bfce91701c7ed0a026035b5deab4d806d64c276e4a80f90151a0fd085370292f4d05ee082de15e730fcfdbbcb9891a40e408540e986fd8d13694a0c82f432998dc6fb8ae056d8eea6d1cf746424531eaa186f2eb82620e0495471a80a0eb6cd0c8b6786187921f2536019f4240977db03085736017207fa0a0342e2f1da062dde3ab6d107fa14cd489612726a90bfbce87d2843647cd22019fbbcce2aa6aa0347dcd59347532b21c614d4f881d0ea01ef9dd17af96e04ee2752e5495fedd1b80a0063b38ac963940e4652e6b5a781619c3f4eefed9cf39f919bdcd9c92c21173e3a0922348dc477395e27728a78f844a278c5280f0c439e6979b94b5a2761efefa48a0156d60ef0ed8404d7cf7d07ef37ef98f3095fe7adcebc80b62c44e99fb12cfb4a0b61f0cd0cbb04c63cd7b207eead0002f5f0b3683d0ee30669973bae75772bd64808080a0615078e5c182ab3cbe1197770b70e97d55333ddc550729a82846daae63d8ef5d8080f85180808080a0bb3269d9a6f9f2b26184f22b64b6469d4e9f3904c3568a87310e0128321d85baa0b0a7e9e138cc12ac748b01ec87976bb4dea907e4c7a1cbeeac9c5002517d21818080808080808080808080ec9e3bf37461065ebb6385ca18662da030da6507bbc09ec381862ef9821c2d0b8c8b23a2560308acbe886a8180f907bbf90211a01a40054ef17103331c164c398c66bf67c9115a454f12c8439f42e4d68569895ba096d0ac8c323242a6023a1f5711a6e33ad40965728f899dd40cf1ba315a50ebcaa088406e397909aa73061db5d232bd591d1be52ad8322579d1a68ef5781f69f721a050012d876070374f3fd88cf2ec41ba5956a931bf7d151921a83302e8c2f948e5a00370a6e8f18bbd181864781a00aa7ec32de94a9edf81dbe7b9094b939ed45e1ba0e37ef99884cf7da1502d183e4e8119a9be58640206b8dd72e4658bc0515c5411a05484afb2665f95e283790cb9b386e9cdc988d4a0baa99623664fed2c022c814ba046eb3cd2fdd93e7b7e0385bac3595f430512e0be589d4b9dc2fc05c329f55681a0f41d9419697ab21c9958b70b328119f88ffe086cfc65dc64f83fc4b66ffa0815a0d76377249b30d75cb05718632695eff04f9ede1634f0fe1085959e4281652bd2a057266a618f533455590cb5ce0e289d185f8712e914249fae44eacaea7366a426a0edc3e781db9937cab57457482a9d1ca2e485c3296233037a80948171e089057ca0e619b0f8a118d50c20ecc0d7b592f16e335a19709ac263ff5f06c2ea214fe3a3a034b1065f37f103ce6465982babf6c498c17dcf1c0291f302ebe823f988534effa03cc27cc12bb6620a714ca3ac64eb86148eb912ef1cd0525ef032ff487edf9653a074dad14093bbcbf25bcf0832f952d35d935b72ee780e9aab51308c053485568c80f90211a0f773bd71df42511f42dd1a65a4764fbf706509bb041e35f7561b61ff3a213459a0d86b37384eee07caad9483e2a3874d7ffbcca7ac9529c3115f3e1b14cc220b54a0e74849f3ce55320f4dab1534016bd2b0a462c481c784a38e9ec7f7238f04d93da0a01a7bf44b631af0140c6cce74a8694458e217be51cdf54f498892e3429286d9a07152f2e8f5d734abf782d4cbbe467e8e57dd9b27c9519d3df89a98b194b15a91a09da2d12f18cf9f72d373c2c2a3be31cd94a076f5bb2bf38f921b2579847ff52da0d70b934b01ac944bb26532e2bdb429cd3dea5a07674e6fb4f60110f4f4bcd423a0390612966f247060c6cbfb2f2856c867eb5f0422ebddd4a84dc2f4492c2c7406a000ccbf152aab7e48003db47c3b7c461f441a85677145e8fff3a4b715d04d18cca0f264311952e362fd0dfe6855851f471cd63255c484e75e9c6cd23c1e6be16b28a08e566d54cf3fe1ca83931a6b2b7a6d6cfd7502c93eea08b67e93f688c726030ba05850360ddcaddf3fd0d378178e5b609f25337df4f86a65534861d466cd27648da023b9926bd7267332071e1be943591d8338936cdcd348e5fcee43eb850046d914a0df489f79b506cbdc46c6bc7666d370529963297f90a2a79d1354937a36136d75a074349b47511de9d66a36bcd28c44c30e53b90ee3dc950276a10fe3e08a64ccaba037d8ca8d0cb0369144a93d6b336e8add8d1ba40cfe8b4835979e97105c42fa8c80f90211a039c354a875621eabf49e1e28635bc8209aee5c93c9c1c907fc645545c6e38da4a01d91816a7472f898b68f5128ecf1a2609d1d32bb9e81ee690d395d7d19218760a028141df8385c6181bb382885b6deaf901bfdc6e26c356ae25144a7c3e5d020daa00b8fc4ff42ab5bcfad0c1b0e372b3ae870e1c7b2ad324255871b36081a478deda049c46a2286c4dfa337258a5e81c503883acc3572146a47b9857c58f4d22abe8aa0a82b065b5dbd554f84a8a834f260bff2814b1de48c3467fc1f1c28ae4ebb34f5a08e9450489a314b495d39f78769e04b9323a68bd52145b512eea9937a18c25248a09e5106013fa57df2c31e53be4abbf68320d4234c1a6ca7f82d2cec50372c3c72a0ff7d779bdf20c442529a428fe7b1c084d5f345dfaf78795d2ae3712843019451a092ae4bb72d64201f5db2d3d65e57cab5afefdfcc3f3fcb967f668faae42397fea0b8d6fe3574819bb444a14f1d0f055ddc5e5cb96ac0f0d5a0a75abf8e9502267fa0a533fa8f93a959356c2c6e9209805487777e6fe063ff130124c40983a4e54432a029cd491a3f9768462c51b144f94ae06cf1e95a8a838c9a729736f93ebc88d0e9a06f43546d1999f40a871445c35a8f91f6f21b2ecb4c4a2e9ef21c79adeda1e020a0bf6d8445297b0bc4a6c9709d6c13d5860c05d1c817451753e3e29d3dc759ac4fa054b68994d72183f621c95e5c348cc76a6b3b6008591385684e1a910665ae766a80f90151a079774a071f5a2fb27c0f1df09096048a098dd7e0573aa15a08b610777b7880aba0d7a74228b4de4c7af76f99fdc27754e339485c3ce45b3191711dc247f45179e080a0aae04e4773a07b363278c207c7341280e2f146a727c245f13796c3db57c0f57ba01963b30ba4737ed72ff0212cf474268bd6904b66f1c1eed7cb762e926fce9f82a0b882973cbf1b7f79a07b59f8041f59075c6f9db957270963ecade6054adfc72d8080808080a00f7a66914f2e1d49a3a843ecba807c6064b258a0248fa58a7eade9a0160583fea0b99a9ef1e7945bfa12bc023ba55a3fcd0274b94e3391224938aa614f3b0190b8a064242b313cd2bc4e4a2843776106532fd35d96b50d3f6fb47c6643e63d6df1bea03673f36a558d068496fcaf8203e0c33e2e304c2c5fc4ca25e982c8ded8e86764a083d26cb3b6265a663235517d7081ec3e244bf4e326898de74e04104a60c89dd380ea9f20e99c073d5475e2e285f9327c2476e0d497a426675ce04a1cf2707c6c24f089880572dd44f0ec03dff9075af90211a01a40054ef17103331c164c398c66bf67c9115a454f12c8439f42e4d68569895ba096d0ac8c323242a6023a1f5711a6e33ad40965728f899dd40cf1ba315a50ebcaa088406e397909aa73061db5d232bd591d1be52ad8322579d1a68ef5781f69f721a050012d876070374f3fd88cf2ec41ba5956a931bf7d151921a83302e8c2f948e5a00370a6e8f18bbd181864781a00aa7ec32de94a9edf81dbe7b9094b939ed45e1ba0e37ef99884cf7da1502d183e4e8119a9be58640206b8dd72e4658bc0515c5411a05484afb2665f95e283790cb9b386e9cdc988d4a0baa99623664fed2c022c814ba046eb3cd2fdd93e7b7e0385bac3595f430512e0be589d4b9dc2fc05c329f55681a0f41d9419697ab21c9958b70b328119f88ffe086cfc65dc64f83fc4b66ffa0815a0d76377249b30d75cb05718632695eff04f9ede1634f0fe1085959e4281652bd2a057266a618f533455590cb5ce0e289d185f8712e914249fae44eacaea7366a426a0edc3e781db9937cab57457482a9d1ca2e485c3296233037a80948171e089057ca0e619b0f8a118d50c20ecc0d7b592f16e335a19709ac263ff5f06c2ea214fe3a3a034b1065f37f103ce6465982babf6c498c17dcf1c0291f302ebe823f988534effa03cc27cc12bb6620a714ca3ac64eb86148eb912ef1cd0525ef032ff487edf9653a074dad14093bbcbf25bcf0832f952d35d935b72ee780e9aab51308c053485568c80f90211a09ea046e98f2d51d264b5e404d84a875e6539a2dc8efdf7228172b021c2c04b8ba05a46a6229aa5f2c912437446d0070a9ee93f3b92d24399f85ac3475ede3fe053a0339a6268472707e2e6e760ddd4e370004ba33ef253e05722972cc17e774412c8a0fe68490daf437b5d62f1996bc1c3d56d475577ae1d0fe3c33a43c59b88945abca026d77d9d418b740d37baa0907428df00d6f33bb52e05337f9e86a17a26fec57ea0b5d9b237f0c71616530df403c1e2b7d299b9a248dfbb3034b399183c2025c0d3a0e2cba9d4884af667c72fe02c25653af58970782324729a6e6d97961e20f9668ca0a1ed23f97c09f5577b32575d189c69910c8cd638b6ce9d784eb8087d11ac3be2a02a156013e3a8e6d442a9b15e2570cd4d758990d0d3db244614ce1e5308e29996a0e868b156b57fabc10950a42f6aeaa80a70167e8b7636ad16a22f675d9d22502aa0a464a89780311d2aed89dd61a9a435ab853de188464c3529d93acb9d22171039a085209b970cd6ab9ab4950dab2825ac9810080edfbfcffd8318670fb73d3e50a3a0c82212252c1190d5385ac7bc3f3ca92a8a895ed9aaef80ba550c77da7f758f91a063332bc6025812a9d06cc5bccdd246f4a4ad309c050699e3be567efc4616aae3a0025618211db40d03a6e720cb121c7e8d24618f25d7aba617306912f99989525da0b3ec4b6f4cd6e08f2ca4c18db3aa2468e898a1c332af949e75df171dfc7ceb5880f90211a0f370ffa89a448f6c97cbcb1af38cf38f3beaa1b8430ac23840974bb7f584d477a0c75c49beb1e38d7ca0607ce7d9ed0eb86f3e74908137e822da9dad989867a190a0d0520793214f1e1a35a31d97fc8d5a599a0cb7c52370756b6a7934e20f89587ba037cf95b58c8714a5b2da08f3b12b6213bda0b6797286f2bf88ee304b17aa16a7a067fb48b12166611f898bdfb2d0c2c07cdcd2d82dde44ff810c11ac7ea31edd1fa06db4bad164544c23bfd03fb7859ccb52898d83f0bac74b36ceb8aa4b8343ca0ba0c7e7e14e47db6c810238d5891145cdde6900d2320f829ba47b00b1d1d9a530fca0b4197b31e17f853cbc29794f1294395e22bb613ce6e642f0394996d829155cb8a010b84595db04c0db73213f0c1cccb80668b0efa59c4e6e89e1387a88b6524bcca064b8812c61d1bc643b14707d53d4d5f8531eb76f35687fb00c61241a5c258c59a01a3fc304b6d0cdd500786f2c48e33024c575416580fdea9a8e8635703207aa16a0d5ec05f99acbbff360df1f46ad08df1614b5c3af279c7f43c1956bfc6ca752e0a09c915fe8e462183fb5e40b52d8b90ff486ae1eefc766b400c9b0e181df09c711a021c20ab9c4ba8369c0d631075991fe6e7374b16f8c939ebb30f7e53e22496239a06fbe9dbc2d98d1637f7ae005e9bd59566a8f94599dcce13187c28e79628c38c4a031de27f4cd74e3e91ac8cec1a98dc5b3f489c580dfd268f1e81702a6396db30e80f8f180a007bb60de2a1cbeb9d99b3f55219d19035f82c92f186eec868d03f7c1e36690ad80808080a007ce83944d44c0d9483743e8b1ae0739ad16690b275335f99190d7ad8a45a7cc808080a09841fe9a32e577935128eeb1919e038b6a4687d476b087a711944eb64fb5ddb0a0c8ffd9d0a147e40611ddf6b26d3316d400ab3662d1f1f99eaf5891c5ae29a47ba0fece42d7c46531faf4c3370aa2be3fa2ea83a08b55c222847c8480ea7f3df862a0ea31037894767fc813f426cc05da5a5ea28c885e5081a29cfcfe05fdea2e6065a0cf98cda997e7781cda270ba4b0b65810acf513a12a89b20e4f6b187ca93c8f4c8080ea9f207b9a0280969d27404fd5a98a03066e3f9f4792e2f2271b7db3c100392d938988011fed9548282356f907e7f90211a01a40054ef17103331c164c398c66bf67c9115a454f12c8439f42e4d68569895ba096d0ac8c323242a6023a1f5711a6e33ad40965728f899dd40cf1ba315a50ebcaa088406e397909aa73061db5d232bd591d1be52ad8322579d1a68ef5781f69f721a050012d876070374f3fd88cf2ec41ba5956a931bf7d151921a83302e8c2f948e5a00370a6e8f18bbd181864781a00aa7ec32de94a9edf81dbe7b9094b939ed45e1ba0e37ef99884cf7da1502d183e4e8119a9be58640206b8dd72e4658bc0515c5411a05484afb2665f95e283790cb9b386e9cdc988d4a0baa99623664fed2c022c814ba046eb3cd2fdd93e7b7e0385bac3595f430512e0be589d4b9dc2fc05c329f55681a0f41d9419697ab21c9958b70b328119f88ffe086cfc65dc64f83fc4b66ffa0815a0d76377249b30d75cb05718632695eff04f9ede1634f0fe1085959e4281652bd2a057266a618f533455590cb5ce0e289d185f8712e914249fae44eacaea7366a426a0edc3e781db9937cab57457482a9d1ca2e485c3296233037a80948171e089057ca0e619b0f8a118d50c20ecc0d7b592f16e335a19709ac263ff5f06c2ea214fe3a3a034b1065f37f103ce6465982babf6c498c17dcf1c0291f302ebe823f988534effa03cc27cc12bb6620a714ca3ac64eb86148eb912ef1cd0525ef032ff487edf9653a074dad14093bbcbf25bcf0832f952d35d935b72ee780e9aab51308c053485568c80f90211a0bd4a15e881f59b773a2d3abf4739a040083cd555544d50898ac774c0a684bcdaa04386cfd7d22ab26558f5d8fef4df28ee8b13b38f0edcb9a9fef8157d94847e4ba008cd569561710c4d91a804b2b178a947967b1f4f531e6f98c5cba7de0c0331c0a0d512820dc5e3f9f7dd46132bcb6043e4db396f87103a2219ee0153c75332a9d2a0907d08ebdfc22e548d5e9631087886fd27bc7f8fb50188b5df3554000f035340a0335b079c17a2af2facf321295ef5cc2573e3a3cc45278d3418bd2bc537f22cc5a00f35443a0c353cd794905d278be929fe841cb2d7982e62aeac13883ccda412dea0aeea6c5977f206b176c252916472fc41dfed44e115a16f46632f49593920e01fa0be3373b1354576e70cc0ca1b0303d8cd7efb2c252a3954f5f63438163a171ac0a0a329950142e0634948b47ee842b167f942ff5f5817dd1f852299ae2ca2ab3736a008187a6bbd0607ce71294d9cd674c46fcbd831d08c1176bd8b1c439af44acabda0e972d0533f615b4a866fbeece4a392af97cb72e475f09764286f7a61322da353a0c187c991a4176f4994e8a5bb99f2865110472233e63e9c3c6412c447c517b9e9a026adc6a85c861c58a3eaf342a867ecaae05660ac9764399f6232e56b2f4c041ba09d6f1e09aa77e65d6d26f7f4a404ef33e907dd79fa567ca8cafcbcb8bf2e7db8a016389f93f88b5d59a38927ae1808a15176ef259a38afd7802f8c561fb082d39e80f90211a0fe9344fb40245b2c37641d91e1b9b326f54360c0a9aec2ca574d139a7ac54165a0e031f1ea9204c960bbdfa776683143a74fae512138f087873603811ac5d47099a09fd43927a03356541ba455ef526465091659242ac14f7c1e1fb7fbf9f0bd912ea0f55b4a00527bda7b27495c3aeccffeac2c94ac76a78f4a55af948866b1ea8429a0011973407aa883a8713d482051e31422215f11c5580066b589900dc8c938ff4fa067d90c936823fdee4ed054131da9f30e1aab2562af203d0fd60250881a097701a0504e618c47395b58bae1bc6b8e1306babdfa063e6005b794aaf71478738a017da041c2b474986658b9e3665ef61afe4bf47680373dec154dc4c7a12b6cd80b7118a018ce141260d79603dadc18169760971849d3088084bd5612c41d5d7d3e32578ea0af46acb57487dbe91c7eba363a5b3824f7123890a8401bd130eff4697d4a022da05123c84a01a82a318452747f0edf107c1a6f334ef637ac65fcd6d16c94a8ac69a069c9cae28305ba2d00ce012eab1a1983104b116ada5e3c0849bfc89be825165fa0a7d8f0337a7f58b97570f3dcb51940e1fb81662e300a6a9b4292a8700b2335efa0a9ba19f993c413e6980064727f35c02757a3be5ec737b7dda86383c9e426769ca08d90a9e3723de64f2124712a835e6c0a3a424d702d25c78a69e9213ddbb18f05a052f4bf9fe90b845a2ac94ed6b08c1dc345866ed4ee803e8b837b26705b409f8080f90131a00b4d45db0c87237182348b4884679e22a17529b8e311cb670a92895c08a1b6b3808080a0e6c2afc3b218f9cc1d0d7c6a6cde6676c963ab286b87d2136241750fc01af111a0636432231ffa2b700b929e69aacd4705f2b69091c6f6096d50e0e57f592c875f80a0d3b04a83743d8937e7ab05b78039b951eebf7f836486a4a9afe4ae516ad5778ca0990b67a30cca6a9d102be962b1ebfbb10f6afa379a075db3cdaca3079ff1acc6a00570c6cda64f4389ce05260f8aea64a505425dc9e1df81e5e112b83e725d3fe280a0d3040c0c3dad3a6c7c6d9228d7a688f414556554d64db8a5e179c36118893b7fa0154968cea62e06c8330c03e5d38ac55ef97a8030e3c2baa0b066c5bdcdee376d80a0126b89c55a408932c79a93452067251fbde2b8bbadd9904ffe5fc0da000a94de8080f851808080808080a071f356e2c1c23c4a7cbe97a3ef4f30f75087bc0ba18b07bf1f37422faa03c8da80808080a0f34dc3cd9af0cbbbd9b0aa6dee8f9c3f9f7b747f687142db72d9ab90122cc4658080808080e39e34e3e90b22c6b1c5c0c8cdd72c32564cf653e40e0f49eb7c04cc77c93b14838210f4f907e9f90211a01a40054ef17103331c164c398c66bf67c9115a454f12c8439f42e4d68569895ba096d0ac8c323242a6023a1f5711a6e33ad40965728f899dd40cf1ba315a50ebcaa088406e397909aa73061db5d232bd591d1be52ad8322579d1a68ef5781f69f721a050012d876070374f3fd88cf2ec41ba5956a931bf7d151921a83302e8c2f948e5a00370a6e8f18bbd181864781a00aa7ec32de94a9edf81dbe7b9094b939ed45e1ba0e37ef99884cf7da1502d183e4e8119a9be58640206b8dd72e4658bc0515c5411a05484afb2665f95e283790cb9b386e9cdc988d4a0baa99623664fed2c022c814ba046eb3cd2fdd93e7b7e0385bac3595f430512e0be589d4b9dc2fc05c329f55681a0f41d9419697ab21c9958b70b328119f88ffe086cfc65dc64f83fc4b66ffa0815a0d76377249b30d75cb05718632695eff04f9ede1634f0fe1085959e4281652bd2a057266a618f533455590cb5ce0e289d185f8712e914249fae44eacaea7366a426a0edc3e781db9937cab57457482a9d1ca2e485c3296233037a80948171e089057ca0e619b0f8a118d50c20ecc0d7b592f16e335a19709ac263ff5f06c2ea214fe3a3a034b1065f37f103ce6465982babf6c498c17dcf1c0291f302ebe823f988534effa03cc27cc12bb6620a714ca3ac64eb86148eb912ef1cd0525ef032ff487edf9653a074dad14093bbcbf25bcf0832f952d35d935b72ee780e9aab51308c053485568c80f90211a0f773bd71df42511f42dd1a65a4764fbf706509bb041e35f7561b61ff3a213459a0d86b37384eee07caad9483e2a3874d7ffbcca7ac9529c3115f3e1b14cc220b54a0e74849f3ce55320f4dab1534016bd2b0a462c481c784a38e9ec7f7238f04d93da0a01a7bf44b631af0140c6cce74a8694458e217be51cdf54f498892e3429286d9a07152f2e8f5d734abf782d4cbbe467e8e57dd9b27c9519d3df89a98b194b15a91a09da2d12f18cf9f72d373c2c2a3be31cd94a076f5bb2bf38f921b2579847ff52da0d70b934b01ac944bb26532e2bdb429cd3dea5a07674e6fb4f60110f4f4bcd423a0390612966f247060c6cbfb2f2856c867eb5f0422ebddd4a84dc2f4492c2c7406a000ccbf152aab7e48003db47c3b7c461f441a85677145e8fff3a4b715d04d18cca0f264311952e362fd0dfe6855851f471cd63255c484e75e9c6cd23c1e6be16b28a08e566d54cf3fe1ca83931a6b2b7a6d6cfd7502c93eea08b67e93f688c726030ba05850360ddcaddf3fd0d378178e5b609f25337df4f86a65534861d466cd27648da023b9926bd7267332071e1be943591d8338936cdcd348e5fcee43eb850046d914a0df489f79b506cbdc46c6bc7666d370529963297f90a2a79d1354937a36136d75a074349b47511de9d66a36bcd28c44c30e53b90ee3dc950276a10fe3e08a64ccaba037d8ca8d0cb0369144a93d6b336e8add8d1ba40cfe8b4835979e97105c42fa8c80f90211a0835183e3fc17ea294afc488fed16f162e5e3cff3941dba08648f9585d3b705c5a055a391cbed811986886851aeea53a6da13567b4eefc9d594b0c6c32d6e09ae04a008469ff2bf301f58f6c60fba00e31b54d6e040b4fc43a04b9a14719ae73aa60da07b4ac112b41c7dc9b17a1131628ef05316ba6b6b84a3e495620da5b923960990a0fd9323e5c70ee1dd8b98c1832eccdd8318536edd32c285b87c7106fffe3e7d43a01757c22d74d4b3f9a35e5c46924db7995bbc37894714ddf1d657cd372490958fa0ddb0c85210a213a5f2644e864eadc57c1f1b382f32e1006468f16f7370f45abba019a6d30e6c1036ce074af62f4f983bf2942c16eba294134cd55fa5034f1819dca08903392d9499f5e48f26a66b4ad351122cd78580885bd0362f317986126b68fea0363bf7e39afa6a4947f236f9b52a723caccc07e25140b98a09afd36236d4bdc6a0b4ac4bd8edddd4136f14a016181cc8838601b65583ef78606bdbad0c6e9a458ea09bb9b10578fa54ce7fea6912316945231c966b3f4dabf450119fed44f0161c02a09c71abfeaba28ca1b32b1a9fb8035effd8cd61942258f48ece804946e4c20773a0bf75bece601dfeb7125b2b30ade79169ab3cb51a3daaf18f9185421f415ac4b6a0a20099e335562ac6efddab2e5b0051116691b6d485c9c9c04b07029e94c88ecca02030587eb7636a2701532f7713a18dc3b20b9a84f9b09ae791b212c8e8d11d2d80f9013180a07c66a5fba687e7aa99d460cca4cbcf6ad39dd771fe8ab9dd3316c4e35586746da0a904ea007747ac6c34f1f493da04d34c7282af8bba09c153d954be35ae360be9a098029051f52b8b548783f5aee7fb339ce833e30fa10f9542d8cba544dbccfbba80a0f742171b55b77f9c63442925e84f19f3c5e1f2e11e87680471ff621188687e8380a0b14d7ad65a3cba3378a324867c0b189541b9a2970d3f90868b6b6c17071c2e9d80a083568ec7250e583dd87e07b3b91105d708eb9dd6bb99ac8a1041fcbfe0d9c517a0c71e33b6fd31e504dd31f9165f2140c8de6c7c8e905064f29e8ee2bfc4041a9380a08a2b5048721202a8357cd330732a8801b1bef2f1f53ca7c0ce5758b7c832c52b80a07c417e4a41579ecc7f12bbf6a9bb4d0131e7084bae90f10916800736d86852988080f8518080808080808080a01b688be6d21e65c9e63eb1974499898b43415f4d6c393f89f138132cdfa417678080808080a0ff559cbd59547a70f6d31c9c0b71ea2b6141f4ad73593be16874707969a4857e8080e59e392e4b0093bb4a557936b589133753c7c5d81614665a63911ac221da4f5b85846ad01780"
        );
        bytes memory rlpHeader = bytes(
            hex"f90220a025297ca1758f85555f22371ee7f141b95dbcd18d390ce060d7363150339d1c32a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794dafea492d9c6733ae3d56b7ed1adb60692c98bc5a01da5779c24f259b0cbff8df30df5483a2349e31fc6641486fe4fddb536d76196a03266c95f01ecf8fcb45b9a8281ad9b445dcec0855c542c9229ee9a21174f3efaa0a6626e0d5ae494bf83217a85524812a915db9c282a0a34134a9b8470abecb0e2b9010001e224b049d01027e0625488e2b032273124490091024110014745028c040cc0100c708104c04422411c0b6466589784069100856a87f488060000ca13212801af745dd6d1858d4cfbab82d9c1b060ae454302f8db758341556118e49a54dcc333721a848a0688a40c45252288009e80009c4114083f0d579304f1982408a476ba00854a88e2bd7501c8085c052b36a5411385d9236829a8040442c0c31700638a9851d97b80fc08c0081494a5541f4218c0162120e9e183086b2c66cad9d9a4d5049e4211420045812008f08098405e8d5882e444fbe4b3c0e40b021200a80ac914394a00088280080417c0a5211a604e04251141088740491818b24a5748a98083f4c6338401c9c38083c023d584637fb2b79f496c6c756d696e61746520446d6f63726174697a6520447374726962757465a0c99cc0ddd2a0e36da85ce9d5506aaf9246c15971c5538cc21822797b4fb678ce8800000000000000008502582ad339"
        );

        oracle.submit_state(user, gauge, time, rlpHeader, rlpProof);
        bool updated = oracle.userUpdated(blockNumber, user, gauge);
        assert(updated);
    }
}
