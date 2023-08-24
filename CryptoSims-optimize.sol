// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TheFunixCryptoSim is ERC721, Ownable  {
   
    constructor() ERC721("TheFunixCryptoSims", "FCS") {		
        createGenesis();
    }
    
    // This struct will be used to represent the attributes of CryptoSim
    struct SimAttributes {
		// 0 -> 3
        uint8 body;
        // 0 -> 7
        uint8 eye;
        // 0 -> 127
        uint8 hairstyle;
        // 0 -> 31
        uint8 outfit;
        // 0 -> 31
        uint8 accessory;
        // 0 -> 3
        uint8 hiddenGenes;
        // 0 - 255
        uint8 generation;
    }

    // This struct will be used to represent one sim
    struct Sim {
        uint32 genes;
        uint256 matronId;
        uint256 sireId;
    }
    
    // List of existing sims. Use as CryptoSims' "database"
    Sim[] public sims;
    
    // Event that will be emitted whenever a new sim is created
    event Birth(
        address owner,
        uint256 id,
        uint256 matronId,
        uint256 sireId,
        uint32 genes
    );

    /** @dev Function to determine a sim's characteristics.
      * @param matronId ID of sim's matron (one parent)
      * @param sireId ID of sim's sire (other parent)
      * @return The sim's new genes
      */
    function generateSimGenes(
        uint256 matronId,
        uint256 sireId
    )
        internal
        returns (uint32)
    {
        SimAttributes memory matronAttr = decodeAttributes(sims[matronId].genes);
        SimAttributes memory sireAttr = decodeAttributes(sims[sireId].genes);

        uint8 x = matronAttr.hiddenGenes;

        if (matronAttr.hiddenGenes == sireAttr.hiddenGenes) {
            x = (x * sireAttr.hiddenGenes + 3) % 4;
        } else if (x < sireAttr.hiddenGenes) {
            x = sireAttr.hiddenGenes;
        }
 
        // Init new object to store new Sim's attributes 
        SimAttributes memory attributes = SimAttributes({
          body: 0,
          eye: 0,
          hairstyle: 0,
          outfit: 0,
          accessory: 0,
          hiddenGenes: 0,
          generation: 0
        });

        attributes.generation = matronAttr.generation + 1;
        if (sireAttr.generation > matronAttr.generation) {
            attributes.generation = sireAttr.generation + 1; 
        }

        attributes.body = (matronAttr.body * sireAttr.body + 3) % 4;
        attributes.eye = (matronAttr.eye + sireAttr.eye) % 8;
        attributes.hairstyle = (sireAttr.hairstyle - matronAttr.hairstyle + 128) % 128;
        attributes.outfit = (matronAttr.outfit + sireAttr.outfit + 1) % 32;
        attributes.accessory = (matronAttr.accessory + sireAttr.accessory) % 32;
        attributes.hiddenGenes = x;

        if (x==0) {
            attributes.eye = sireAttr.eye;
            attributes.hairstyle = sireAttr.hairstyle;
        } else if (x==1) {
            attributes.eye = matronAttr.eye;
        } else if (x==2) {
            attributes.outfit--;
            attributes.accessory += 31;
        } else if  (x==3) {
            attributes.hairstyle = matronAttr.hairstyle;
            attributes.outfit--;
            attributes.accessory += 31;
        }

        return encodeAttributes(attributes);
    }


    /** @dev Function to create a new sim
      * @param matron ID of new sim's matron (one parent)
      * @param sire ID of new sim's sire (other parent)
      * @param owner Address of new sim's owner
      * @return The new sim's ID
      */
    function createSim(
        uint256 matron,
        uint256 sire,
        address owner
    )
        internal
        returns (uint)
    {
        require(owner != address(0));

        // Create new sim attributes based on matron and sire
        uint32 newGenes = generateSimGenes(matron, sire);
        
        Sim memory newSim = Sim({
            genes: newGenes,
            matronId: matron,
            sireId: sire
        });

        // Add new Sim to array of sims
        sims.push(newSim);
        uint256 newSimId =  sims.length -  1;

        // Create new NFT with ID is New Sim's ID, and owner is defined
        super._mint(owner, newSimId);

        // Emit Birth event
        emit Birth(
            owner,
            newSimId,
            newSim.matronId,
            newSim.sireId,
            newSim.genes
        );
        return newSimId;
    }


    function createGenesis() internal {
    
        SimAttributes memory firstAtrributes = SimAttributes({
          body: 0,
          eye: 0,
          hairstyle: 0,
          outfit: 0,
          accessory: 0,
          hiddenGenes: 0,
          generation: 0
        });

        SimAttributes memory secondAtrributes = SimAttributes({
          body: 3,
          eye: 7,
          hairstyle: 127,
          outfit: 31,
          accessory: 31,
          hiddenGenes: 0,
          generation: 0
        });
        
        sims.push(Sim({
            genes: 0,
            matronId: 0,
            sireId: 0
        }));

        super._mint(msg.sender, 0);

        sims.push(Sim({
            genes: 4294966272,
            matronId: 0,
            sireId: 0
        }));

        super._mint(msg.sender, 1);

    }

  
    /** @dev Function to allow user to buy a new sim (calls createSim())
      * @return The new sim's ID
      */
    function buySim() external payable returns (uint256) {
        require(msg.value == 0.02 ether);
        return createSim(0, (sims.length - 1) % sims.length, msg.sender);
    }
    
    /** @dev Function to breed 2 sims to create a new one
      * @param matronId ID of new sim's matron (one parent)
      * @param sireId ID of new sim's sire (other parent)
      * @return The new sim's ID
      */
    function breedSim(uint256 matronId, uint256 sireId) external payable returns (uint256) {
        require(msg.value == 0.05 ether);
        return createSim(matronId, sireId, msg.sender);
    }
    
    /** @dev Function to retrieve a specific sim's details.
      * @param simId ID of the sim who's details will be retrieved
      * @return An array, [Sim's ID, Sim's genes, matron's ID, sire's ID]
      */
    function getSimDetails(uint256 simId) external view returns (uint256, uint32, uint256, uint256) {
        Sim storage sim = sims[simId];
        return (simId, sim.genes, sim.matronId, sim.sireId);
    }
    
    /** @dev Function to get a list of owned sims' IDs
      * @return A uint array which contains IDs of all owned sims
      */
    function ownedSims() external view returns(uint256[] memory) {
        uint256 simCount = balanceOf(msg.sender);
        if (simCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](simCount);
            uint256 totalSims = sims.length;
            uint256 resultIndex = 0;
            uint256 simId = 0;
            while (simId < totalSims) {

                if (ownerOf(simId) == msg.sender) {
                    result[resultIndex] = simId;
                    resultIndex = resultIndex + 1;
                }

                simId = simId + 1;
            }
            return result;
        }
    }
	
	function encodeAttributes(SimAttributes memory attributes) internal returns (uint32) {
        uint32 genes = 0;
            genes = uint32(attributes.body << 30) | 
                    uint32(attributes.eye << 27) | 
                    uint32(attributes.hairstyle << 20) | 
                    uint32(attributes.outfit << 15) | 
                    uint32(attributes.accessory << 10) | 
                    uint32(attributes.hiddenGenes << 8) | 
                    uint32(attributes.generation);
        return genes;
	}

    function decodeAttributes(uint32 genes) internal returns (SimAttributes memory) {
        SimAttributes memory attributes = SimAttributes({
          body: 0,
          eye: 0,
          hairstyle: 0,
          outfit: 0,
          accessory: 0,
          hiddenGenes: 0,
          generation: 0
        });

        attributes.body = uint8(genes >> 30);
        attributes.eye = uint8((genes << 2) >> 29);
        attributes.hairstyle = uint8((genes << 5) >> 25);
        attributes.outfit = uint8((genes << 12) >> 27);
        attributes.accessory = uint8((genes << 17) >> 27);
        attributes.hiddenGenes = uint8((genes << 22) >> 30);
        attributes.generation = uint8((genes << 24) >> 24);

        return attributes;
	}
}