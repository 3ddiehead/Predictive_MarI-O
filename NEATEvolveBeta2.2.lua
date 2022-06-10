-- MarI/O by SethBling
-- Feel free to use this code, but please do not redistribute it.
-- Intended for use with the BizHawk emulator and Super Mario World or Super Mario Bros. ROM.
-- For SMW, make sure you have a save state named "DP1.state" at the beginning of a level,
-- and put a copy in both the Lua folder and the root directory of BizHawk.

if gameinfo.getromname() == "Super Mario World (USA)" then
	Filename = "DP1.state"
	ButtonNames = {
		"A",
		"B",
		"X",
		"Y",
		"Up",
		"Down",
		"Left",
		"Right",
	}
elseif gameinfo.getromname() == "Super Mario Bros. (W) [!]" then
	Filename = "SMB1-1.state"
	ButtonNames = {
		"A",
		"B",
		"Up",
		"Down",
		"Left",
		"Right",
	}
end

BoxRadius = 6
InputSize = (BoxRadius*2+1)*(BoxRadius*2+1)

Inputs = InputSize+1
Outputs = #ButtonNames
--MemorySize determines the number of frames that will be stored in MarI/O's working memory
MemorySize = 5
--MemoryInterval determines the number of frames between each stored frame in MarI/O's working memory (time resolution)
MemoryInterval = 5

Population = 300
DeltaDisjoint = 2.0
DeltaWeights = 0.4
DeltaThreshold = 1.0

StaleSpecies = 15

MutateConnectionsChance = 0.25
PerturbChance = 0.90
CrossoverChance = 0.75
LinkMutationChance = 2.0
NodeMutationChance = 0.50
BiasMutationChance = 0.40
StepSize = 0.1
DisableMutationChance = 0.4
EnableMutationChance = 0.2

TimeoutConstant = 20

MaxNodes = 1000000

function getPositions()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		marioX = memory.read_s16_le(0x94)
		marioY = memory.read_s16_le(0x96)
		
		local layer1x = memory.read_s16_le(0x1A);
		local layer1y = memory.read_s16_le(0x1C);
		
		screenX = marioX-layer1x
		screenY = marioY-layer1y
	elseif gameinfo.getromname() == "Super Mario Bros. (W) [!]" then
		marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte(0x86)
		marioY = memory.readbyte(0x03B8)+16
	
		screenX = memory.readbyte(0x03AD)
		screenY = memory.readbyte(0x03B8)
	end
end

function getTile(dx, dy)
	if gameinfo.getromname() == "Super Mario World (USA)" then
		x = math.floor((marioX+dx+8)/16)
		y = math.floor((marioY+dy)/16)
		
		return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
	elseif gameinfo.getromname() == "Super Mario Bros. (W) [!]" then
		local x = marioX + dx + 8
		local y = marioY + dy - 16
		local page = math.floor(x/256)%2

		local subx = math.floor((x%256)/16)
		local suby = math.floor((y - 32)/16)
		local addr = 0x500 + page*13*16+suby*16+subx
		
		if suby >= 13 or suby < 0 then
			return 0
		end
		
		if memory.readbyte(addr) ~= 0 then
			return 1
		else
			return 0
		end
	end
end

function getSprites()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		local sprites = {}
		for slot=0,11 do
			local status = memory.readbyte(0x14C8+slot)
			if status ~= 0 then
				spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
				spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
				sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey}
			end
		end		
		
		return sprites
	elseif gameinfo.getromname() == "Super Mario Bros. (W) [!]" then
		local sprites = {}
		for slot=0,4 do
			local enemy = memory.readbyte(0xF+slot)
			if enemy ~= 0 then
				local ex = memory.readbyte(0x6E + slot)*0x100 + memory.readbyte(0x87+slot)
				local ey = memory.readbyte(0xCF + slot)+24
				sprites[#sprites+1] = {["x"]=ex,["y"]=ey}
			end
		end
		
		return sprites
	end
end

function getExtendedSprites()
	if gameinfo.getromname() == "Super Mario World (USA)" then
		local extended = {}
		for slot=0,11 do
			local number = memory.readbyte(0x170B+slot)
			if number ~= 0 then
				spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
				spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
				extended[#extended+1] = {["x"]=spritex, ["y"]=spritey}
			end
		end		
		
		return extended
	elseif gameinfo.getromname() == "Super Mario Bros. (W) [!]" then
		return {}
	end
end

function getInputs()
	getPositions()
	
	sprites = getSprites()
	extended = getExtendedSprites()
	
	local inputs = {}
	
	for dy=-BoxRadius*16,BoxRadius*16,16 do
		for dx=-BoxRadius*16,BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			
			tile = getTile(dx, dy)
			if tile == 1 and marioY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
			
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (marioX+dx))
				disty = math.abs(sprites[i]["y"] - (marioY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = -1
				end
			end

			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (marioX+dx))
				disty = math.abs(extended[i]["y"] - (marioY+dy))
				if distx < 8 and disty < 8 then
					inputs[#inputs] = -1
				end
			end
		end
	end
	
	--mariovx = memory.read_s8(0x7B)
	--mariovy = memory.read_s8(0x7D)
	
	return inputs
end

function sigmoid(x)
	return 2/(1+math.exp(-4.9*x))-1
end

function newInnovation(pool)
	pool.innovation = pool.innovation + 1
	return pool.innovation
end

function newPool()
	local pool = {}
	pool.species = {}
	pool.generation = 0
	pool.innovation = Outputs
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.currentFrame = 0
	pool.maxFitness = 0
	
	return pool
end

function newSpecies()
	local species = {}
	species.topFitness = 0
	species.staleness = 0
	species.genomes = {}
	species.averageFitness = 0
	
	return species
end

function newGenome()
	local genome = {}
	genome.genes = {}
	genome.fitness = 0
	genome.adjustedFitness = 0
	genome.network = {}
	genome.maxneuron = 0
	genome.globalRank = 0
	genome.mutationRates = {}
	genome.mutationRates["connections"] = MutateConnectionsChance
	genome.mutationRates["link"] = LinkMutationChance
	genome.mutationRates["bias"] = BiasMutationChance
	genome.mutationRates["node"] = NodeMutationChance
	genome.mutationRates["enable"] = EnableMutationChance
	genome.mutationRates["disable"] = DisableMutationChance
	genome.mutationRates["step"] = StepSize
	
	return genome
end

function copyGenome(genome)
	local genome2 = newGenome()
	for g=1,#genome.genes do
		table.insert(genome2.genes, copyGene(genome.genes[g]))
	end
	genome2.maxneuron = genome.maxneuron
	genome2.mutationRates["connections"] = genome.mutationRates["connections"]
	genome2.mutationRates["link"] = genome.mutationRates["link"]
	genome2.mutationRates["bias"] = genome.mutationRates["bias"]
	genome2.mutationRates["node"] = genome.mutationRates["node"]
	genome2.mutationRates["enable"] = genome.mutationRates["enable"]
	genome2.mutationRates["disable"] = genome.mutationRates["disable"]
	
	return genome2
end

function basicGenome(pool)
	local genome = newGenome()
	local innovation = 1

	genome.maxneuron = Inputs
	mutate(pool, genome)
	
	return genome
end

function newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0
	
	return gene
end

function copyGene(gene)
	local gene2 = newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation
	
	return gene2
end

function newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0
	
	return neuron
end

function generatePerceptualNetwork(genome)
	local network = {}
	network.neurons = {}
	
	for i=1,Inputs do
		network.neurons[i] = newNeuron()
	end
	
	for o=1,Outputs do
		network.neurons[MaxNodes+o] = newNeuron()
	end

	--[[Initializing prediction differential neurons
	for d=1,Inputs do
		network.neurons[Inputs+d] = newNeuron()
	end]]

	table.sort(genome.genes, function (a,b)
		return (a.out < b.out)
	end)
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then
				network.neurons[gene.out] = newNeuron()
			end
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			if network.neurons[gene.into] == nil then
				network.neurons[gene.into] = newNeuron()
			end
		end
	end
	
	genome.network = network
end

function generatePredictiveNetwork(genome)
	local network = {}
	network.neurons = {}
	
	for i=1,Inputs do
		network.neurons[i] = newNeuron()
	end
	
	for o=1,Outputs do
		network.neurons[Inputs+o] = newNeuron()
	end

	--Initializing memory neurons
	--input memory begins after current input and current output (176 for SMB, 178 for SMW)
	--output memory begins after input memory
	for m=1,MemorySize do
		for i=1,Inputs do
			network.neurons[m*Inputs+m*Outputs+i] = newNeuron()
		end
		for o=1,Outputs do
			network.neurons[(m+1)*Inputs+m*Outputs+o] = newNeuron()
		end
	end

	--Initializing predictive output neurons
	--Input and output prediction neurons begin after memory neurons, placement depends on the size of the MemorySize variable
	--Potential addition is a PredSize variable, for predicting furthur in advance.
	for i=1,Inputs do
		network.neurons[MaxNodes+i] = newNeuron()
	end
	for o=1,Outputs do
		network.neurons[MaxNodes+Inputs+o] = newNeuron()
	end

	table.sort(genome.genes, function (a,b)
		return (a.out < b.out)
	end)
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then
				network.neurons[gene.out] = newNeuron()
			end
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			if network.neurons[gene.into] == nil then
				network.neurons[gene.into] = newNeuron()
			end
		end
	end
	
	genome.network = network
end

function evaluatePerceptualNetwork(network, inputs)
	table.insert(inputs, 1)
	if #inputs ~= Inputs then
		console.writeline("Incorrect number of neural network inputs.")
		return {}
	end
	
	for i=1,Inputs do
		network.neurons[i].value = inputs[i]
	end

	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end
		
		if #neuron.incoming > 0 then
			neuron.value = sigmoid(sum)
		end
	end
	
	local outputs = {}
	for o=1,Outputs do
		local button = "P1 " .. ButtonNames[o]
		if network.neurons[MaxNodes+o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end
	
	return outputs
end

function evaluatePredictiveNetwork(network, playnetwork)

	--Replace older memory with newer memory for input and output
	for m=MemorySize,1,-1 do
		for i=1,Inputs do
			network.neurons[m*Inputs+m*Outputs+i] = network.neurons[(m-1)*Inputs+(m-1)*Outputs+i]
		end
		for o=1,Outputs do
			network.neurons[(m+1)*Inputs+m*Outputs+o] =  network.neurons[m*Inputs+(m-1)*Outputs+o]
		end
	end

	--Refresh current states of input and output
	for i=1,Inputs do
		network.neurons[i] = playnetwork.neurons[i]
	end

	for o=1,Outputs do
		if playnetwork.neurons[MaxNodes+o].value > 0 then
			network.neurons[Inputs+o].value = 1
		else
			network.neurons[Inputs+o].value = 0
		end
	end

	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end
		
		if #neuron.incoming > 0 then
			neuron.value = sigmoid(sum)
		end
	end
	
	prediction = {}
	for n=1,Inputs+Outputs do
		prediction[n] = network.neurons[MaxNodes+n].value
	end

	return prediction
end

function crossover(g1, g2)
	-- Make sure g1 is the higher fitness genome
	if g2.fitness > g1.fitness then
		tempg = g1
		g1 = g2
		g2 = tempg
	end

	local child = newGenome()
	
	local innovations2 = {}
	for i=1,#g2.genes do
		local gene = g2.genes[i]
		innovations2[gene.innovation] = gene
	end
	
	for i=1,#g1.genes do
		local gene1 = g1.genes[i]
		local gene2 = innovations2[gene1.innovation]
		if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
			table.insert(child.genes, copyGene(gene2))
		else
			table.insert(child.genes, copyGene(gene1))
		end
	end
	
	child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)
	
	for mutation,rate in pairs(g1.mutationRates) do
		child.mutationRates[mutation] = rate
	end
	
	return child
end

function randomPlayNeuron(pool, genes, nonInput)
	local neurons = {}

	if not nonInput then
		for i=1,Inputs do
			neurons[i] = true
		end
	end

	for o=1,Outputs do
		neurons[MaxNodes+o] = true
	end


	for i=1,#genes do
		if (not nonInput) or genes[i].into > Inputs then
			neurons[genes[i].into] = true
		end
		if (not nonInput) or genes[i].out > Inputs then
			neurons[genes[i].out] = true
		end
	end

	local count = 0
	for _,_ in pairs(neurons) do
		count = count + 1
	end
	local n = math.random(1, count)
	
	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then
			return k
		end
	end
	
	return 0
end

function randomPredNeuron(pool, genes, nonInput)
	local neurons = {}

	if not nonInput then
		for i=1,(pool.memorySize+1)*(Inputs+Outputs) do
			neurons[i] = true
		end
	end

	for p=1,Inputs do
		neurons[MaxNodes+p] = true
	end

	for i=1,#genes do
		if (not nonInput) or genes[i].into > (pool.memorySize+1)*(Inputs+Outputs) then
			neurons[genes[i].into] = true
		end
		if (not nonInput) or genes[i].out > (pool.memorySize+1)*(Inputs+Outputs) then
			neurons[genes[i].out] = true
		end
	end

	local count = 0
	for _,_ in pairs(neurons) do
		count = count + 1
	end
	local n = math.random(1, count)
	
	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then
			return k
		end
	end
	
	return 0
end

function containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then
			return true
		end
	end
end

function pointMutate(genome)
	local step = genome.mutationRates["step"]
	
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < PerturbChance then
			gene.weight = gene.weight + math.random() * step*2 - step
		else
			gene.weight = math.random()*4-2
		end
	end
end

function point(genome)
	local step = genome.mutationRates["step"]
	
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < PerturbChance then
			gene.weight = gene.weight + math.random() * step*2 - step
		else
			gene.weight = math.random()*4-2
		end
	end
end

function linkMutate(pool, genome, forceBias)
	local neuron1
	local neuron2
	if pool.memorySize ~= 0 then
		neuron1 = randomPredNeuron(pool, genome.genes, false)
		neuron2 = randomPredNeuron(pool, genome.genes, true)
	else
		neuron1 = randomPlayNeuron(pool, genome.genes, false)
		neuron2 = randomPlayNeuron(pool, genome.genes, true)
	end

	local newLink = newGene()
	if (neuron1 <= Inputs and neuron2 <= Inputs) or (neuron1 <= (pool.memorySize+1)*(Inputs+Outputs) and neuron2 <= (pool.memorySize+1)*(Inputs+Outputs) and pool.memorySize ~= 0) then
		--Both input nodes
		return
	end

	if neuron2 <= Inputs or (neuron2 <= (pool.memorySize+1)*(Inputs+Outputs) and pool.memorySize ~= 0) then
		-- Swap output and input
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end

	newLink.into = neuron1
	newLink.out = neuron2
	
	if forceBias then
		newLink.into = Inputs
	end

	if containsLink(genome.genes, newLink) then
		return
	end
	newLink.innovation = newInnovation(pool)
	newLink.weight = math.random()*4-2
	
	table.insert(genome.genes, newLink)
end

function nodeMutate(pool, genome)
	if #genome.genes == 0 then
		return
	end

	genome.maxneuron = genome.maxneuron + 1

	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then
		return
	end
	gene.enabled = false
	
	local gene1 = copyGene(gene)
	gene1.out = genome.maxneuron
	gene1.weight = 1.0
	gene1.innovation = newInnovation(pool)
	gene1.enabled = true
	table.insert(genome.genes, gene1)
	
	local gene2 = copyGene(gene)
	gene2.into = genome.maxneuron
	gene2.innovation = newInnovation(pool)
	gene2.enabled = true
	table.insert(genome.genes, gene2)
end

function enableDisableMutate(genome, enable)
	local candidates = {}
	for _,gene in pairs(genome.genes) do
		if gene.enabled == not enable then
			table.insert(candidates, gene)
		end
	end
	
	if #candidates == 0 then
		return
	end
	
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = not gene.enabled
end

function mutate(pool, genome)
	for mutation,rate in pairs(genome.mutationRates) do
		if math.random(1,2) == 1 then
			genome.mutationRates[mutation] = 0.95*rate
		else
			genome.mutationRates[mutation] = 1.05263*rate
		end
	end

	if math.random() < genome.mutationRates["connections"] then
		pointMutate(genome)
	end
	
	local p = genome.mutationRates["link"]
	while p > 0 do
		if math.random() < p then
			linkMutate(pool, genome, false)
		end
		p = p - 1
	end

	p = genome.mutationRates["bias"]
	while p > 0 do
		if math.random() < p then
			linkMutate(pool, genome, true)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["node"]
	while p > 0 do
		if math.random() < p then
			nodeMutate(pool, genome)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["enable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, true)
		end
		p = p - 1
	end

	p = genome.mutationRates["disable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, false)
		end
		p = p - 1
	end
end

function disjoint(genes1, genes2)
	local i1 = {}
	for i = 1,#genes1 do
		local gene = genes1[i]
		i1[gene.innovation] = true
	end

	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = true
	end
	
	local disjointGenes = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if not i2[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	for i = 1,#genes2 do
		local gene = genes2[i]
		if not i1[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	local n = math.max(#genes1, #genes2)
	
	return disjointGenes / n
end

function weights(genes1, genes2)
	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = gene
	end

	local sum = 0
	local coincident = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if i2[gene.innovation] ~= nil then
			local gene2 = i2[gene.innovation]
			sum = sum + math.abs(gene.weight - gene2.weight)
			coincident = coincident + 1
		end
	end
	
	return sum / coincident
end
	
function sameSpecies(genome1, genome2)
	local dd = DeltaDisjoint*disjoint(genome1.genes, genome2.genes)
	local dw = DeltaWeights*weights(genome1.genes, genome2.genes) 
	return dd + dw < DeltaThreshold
end

function rankGlobally(pool)
	local global = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		for g = 1,#species.genomes do
			table.insert(global, species.genomes[g])
		end
	end
	table.sort(global, function (a,b)
		return (a.fitness < b.fitness)
	end)
	
	for g=1,#global do
		global[g].globalRank = g
	end
end

function calculateAverageFitness(species)
	local total = 0
	
	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end
	
	species.averageFitness = total / #species.genomes
end

function totalAverageFitness(pool)
	local total = 0
	for s = 1,#pool.species do
		local species = pool.species[s]
		total = total + species.averageFitness
	end

	return total
end

function cullSpecies(pool,cutToOne)
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		local remaining = math.ceil(#species.genomes/2)
		if cutToOne then
			remaining = 1
		end
		while #species.genomes > remaining do
			table.remove(species.genomes)
		end
	end
end

function breedChild(pool, species)
	local child = {}
	if math.random() < CrossoverChance then
		g1 = species.genomes[math.random(1, #species.genomes)]
		g2 = species.genomes[math.random(1, #species.genomes)]
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		child = copyGenome(g)
	end
	
	mutate(pool, child)
	
	return child
end

function removeStaleSpecies(pool)
	local survived = {}

	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		if species.staleness < StaleSpecies or species.topFitness >= pool.maxFitness then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end

function removeWeakSpecies(pool)
	local survived = {}

	local sum = totalAverageFitness(pool)
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end


function addToSpecies(pool, child)
	local foundSpecies = false
	for s=1,#pool.species do
		local species = pool.species[s]
		if not foundSpecies and sameSpecies(child, species.genomes[1]) then
			table.insert(species.genomes, child)
			foundSpecies = true
		end
	end
	
	if not foundSpecies then
		local childSpecies = newSpecies()
		table.insert(childSpecies.genomes, child)
		table.insert(pool.species, childSpecies)
	end
end

function newGeneration(pool)
	cullSpecies(pool,false) -- Cull the bottom half of each species
	rankGlobally(pool)
	removeStaleSpecies(pool)
	rankGlobally(pool)
	for s = 1,#pool.species do
		local species = pool.species[s]
		calculateAverageFitness(species)
	end
	removeWeakSpecies(pool)
	local sum = totalAverageFitness(pool)
	local children = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population) - 1
		for i=1,breed do
			table.insert(children, breedChild(pool, species))
		end
	end
	cullSpecies(pool, true) -- Cull all but the top member of each species
	while #children + #pool.species < Population do
		local species = pool.species[math.random(1, #pool.species)]
		table.insert(children, breedChild(pool, species))
	end
	for c=1,#children do
		local child = children[c]
		addToSpecies(pool, child)
	end
	
	pool.generation = pool.generation + 1
	
	writeFile(pool, "backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
end
	
function initializePool()
	--Split pool into two organisms, the player pool and the predictor pool.  This will make fitness checking easier and gene creation independent for the two.
	playpool = newPool()
	playpool.memorySize = 0
	predpool = newPool()
	predpool.memorySize = MemorySize

	for i=1,Population do
		playbasic = basicGenome(playpool)
		predbasic = basicGenome(predpool)
		addToSpecies(playpool, playbasic)
		addToSpecies(predpool, predbasic)
	end

	initializeRun()
end

function clearJoypad()
	controller = {}
	for b = 1,#ButtonNames do
		controller["P1 " .. ButtonNames[b]] = false
	end
	joypad.set(controller)
end

function initializeRun()
	savestate.load(Filename);
	rightmost = 0
	playpool.currentFrame = 0
	predpool.currentFrame = 0
	timeout = TimeoutConstant
	clearJoypad()
	
	--Initialize networks for both the player pool and predictor pool.
	local playspecies = playpool.species[playpool.currentSpecies]
	local playgenome = playspecies.genomes[playpool.currentGenome]
	generatePerceptualNetwork(playgenome)
	local predspecies = predpool.species[predpool.currentSpecies]
	predgenome = predspecies.genomes[predpool.currentGenome]
	generatePredictiveNetwork(predgenome)

	inputs = getInputs()
	table.insert(inputs, 1)
	if #inputs ~= Inputs then
		console.writeline("Incorrect number of neural network inputs.")
		return {}
	end

	--Initialize all memory frames to starting frame position
	for m=1,MemorySize+1 do
		for i=1,Inputs do
			predgenome.network.neurons[(m-1)*Inputs+(m-1)*Outputs+i].value = inputs[i]
		end
	end

	predgenome.fitness = 1
	prediction = evaluatePredictiveNetwork(predgenome.network, playgenome.network)

	evaluateCurrent()
end

function evaluateCurrent()
	local playspecies = playpool.species[playpool.currentSpecies]
	local playgenome = playspecies.genomes[playpool.currentGenome]

	inputs = getInputs()

	controller = evaluatePerceptualNetwork(playgenome.network, inputs)
	
	if controller["P1 Left"] and controller["P1 Right"] then
		controller["P1 Left"] = false
		controller["P1 Right"] = false
	end
	if controller["P1 Up"] and controller["P1 Down"] then
		controller["P1 Up"] = false
		controller["P1 Down"] = false
	end

	joypad.set(controller)

	local fitbits = 0
	local unfitness = 0
	for n=1,Inputs+Outputs do
		if predgenome.network.neurons[n].value ~= 0 then
			fitbits = fitbits + 1
			unfitness = unfitness + math.abs(predgenome.network.neurons[n].value - prediction[n])
		end
	end
	predgenome.fitness = predgenome.fitness + fitbits - unfitness

	prediction = evaluatePredictiveNetwork(predgenome.network, playgenome.network)

end

if playpool == nil or predpool == nil then
	initializePool()
end

function nextGenome(pool)
	pool.currentGenome = pool.currentGenome + 1
	if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
		pool.currentGenome = 1
		pool.currentSpecies = pool.currentSpecies+1
		if pool.currentSpecies > #pool.species then
			newGeneration(pool)
			pool.currentSpecies = 1
		end
	end
end

function fitnessAlreadyMeasured(pool)
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	return genome.fitness ~= 0
end

function displayPlayGenome(genome)
	local network = genome.network
	local cells = {}
	local i = 1
	local cell = {}
	for dy=-BoxRadius,BoxRadius do
		for dx=-BoxRadius,BoxRadius do
			cell = {}
			cell.x = 50+5*dx
			cell.y = 70+5*dy
			cell.value = network.neurons[i].value
			cells[i] = cell
			i = i + 1
		end
	end
	local biasCell = {}
	biasCell.x = 80
	biasCell.y = 110
	biasCell.value = network.neurons[Inputs].value
	cells[Inputs] = biasCell
	
	for o = 1,Outputs do
		cell = {}
		cell.x = 220
		cell.y = 30 + 8 * o
		cell.value = network.neurons[MaxNodes + o].value
		cells[MaxNodes+o] = cell
		local color
		if cell.value > 0 then
			color = 0xFF0000FF
		else
			color = 0xFF000000
		end
		gui.drawText(223, 24+8*o, ButtonNames[o], color, 9)
	end
	
	for n,neuron in pairs(network.neurons) do
		cell = {}
		if n > Inputs and n <= MaxNodes then
			cell.x = 140
			cell.y = 40
			cell.value = neuron.value
			cells[n] = cell
		end
	end
	
	for n=1,4 do
		for _,gene in pairs(genome.genes) do
			if gene.enabled then
				local c1 = cells[gene.into]
				local c2 = cells[gene.out]
				if gene.into > Inputs and gene.into <= MaxNodes then
					c1.x = 0.75*c1.x + 0.25*c2.x
					if c1.x >= c2.x then
						c1.x = c1.x - 40
					end
					if c1.x < 90 then
						c1.x = 90
					end
					
					if c1.x > 220 then
						c1.x = 220
					end
					c1.y = 0.75*c1.y + 0.25*c2.y
					
				end
				if gene.out > Inputs and gene.out <= MaxNodes then
					c2.x = 0.25*c1.x + 0.75*c2.x
					if c1.x >= c2.x then
						c2.x = c2.x + 40
					end
					if c2.x < 90 then
						c2.x = 90
					end
					if c2.x > 220 then
						c2.x = 220
					end
					c2.y = 0.25*c1.y + 0.75*c2.y
				end
			end
		end
	end
	
	gui.drawBox(50-BoxRadius*5-3,70-BoxRadius*5-3,50+BoxRadius*5+2,70+BoxRadius*5+2,0xFF000000, 0x80808080)
	for n,cell in pairs(cells) do
		if n > Inputs or cell.value ~= 0 then
			local color = math.floor((cell.value+1)/2*256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local opacity = 0xFF000000
			if cell.value == 0 then
				opacity = 0x50000000
			end
			color = opacity + color*0x10000 + color*0x100 + color
			gui.drawBox(cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
		end
	end
	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			local opacity = 0xA0000000
			if c1.value == 0 then
				opacity = 0x20000000
			end
			
			local color = 0x80-math.floor(math.abs(sigmoid(gene.weight))*0x80)
			if gene.weight > 0 then 
				color = opacity + 0x8000 + 0x10000*color
			else
				color = opacity + 0x800000 + 0x100*color
			end
			gui.drawLine(c1.x+1, c1.y, c2.x-3, c2.y, color)
		end
	end
	
	gui.drawBox(49,71,51,78,0x00000000,0x80FF0000)
	
	if forms.ischecked(showMutationRates) then
		local pos = 100
		for mutation,rate in pairs(genome.mutationRates) do
			gui.drawText(100, pos, mutation .. ": " .. rate, 0xFF000000, 10)
			pos = pos + 8
		end
	end
end

function displayPredGenome(genome)
	local network = genome.network
	local cells = {}
	local i = 1
	local cell = {}

	for dy=-BoxRadius,BoxRadius do
		for dx=-BoxRadius,BoxRadius do
			cell = {}
			cell.x = 40+5*dx
			cell.y = 70+5*dy
			cell.value = network.neurons[Inputs+Outputs+i].value
			cells[i] = cell
			i = i + 1
		end
	end

	for m=1,MemorySize-1 do
		i = 1
		for dy=-BoxRadius,BoxRadius do
			for dx=-BoxRadius,BoxRadius do
				cell = {}
				cell.x = 40+5*dx
				cell.y = 70+5*dy
				cell.value = network.neurons[(m+1)*(Inputs+Outputs)+i].value
				cell.age = m
				cells[m*(Inputs+Outputs)+i] = cell
				i = i + 1
			end
		end
	end

	local biasCell = {}
	biasCell.x = 70
	biasCell.y = 110
	biasCell.value = network.neurons[2*Inputs+Outputs].value
	cells[Inputs] = biasCell

	i = 1
	for dy=-BoxRadius,BoxRadius do
		for dx=-BoxRadius,BoxRadius do
			cell = {}
			cell.x = 210+5*dx
			cell.y = 70+5*dy
			cell.value = network.neurons[MaxNodes+i].value
			cells[MaxNodes+i] = cell
			i = i + 1
		end
	end
	local biasPCell = {}
	biasPCell.x = 240
	biasPCell.y = 110
	biasPCell.value = network.neurons[MaxNodes+Inputs].value
	cells[MaxNodes+Inputs] = biasPCell
	
	for n,neuron in pairs(network.neurons) do
		cell = {}
		if n > Inputs and n <= MaxNodes then
			cell.x = 140
			cell.y = 40
			cell.value = neuron.value
			cells[n] = cell
		end
	end
	
	for n=1,4 do
		for _,gene in pairs(genome.genes) do
			if gene.enabled then
				local c1 = cells[gene.into]
				local c2 = cells[gene.out]
				if gene.into > Inputs and gene.into <= MaxNodes then
					c1.x = 0.75*c1.x + 0.25*c2.x
					if c1.x >= c2.x then
						c1.x = c1.x - 40
					end
					if c1.x < 90 then
						c1.x = 90
					end
					
					if c1.x > 220 then
						c1.x = 220
					end
					c1.y = 0.75*c1.y + 0.25*c2.y
					
				end
				if gene.out > Inputs and gene.out <= MaxNodes then
					c2.x = 0.25*c1.x + 0.75*c2.x
					if c1.x >= c2.x then
						c2.x = c2.x + 40
					end
					if c2.x < 90 then
						c2.x = 90
					end
					if c2.x > 220 then
						c2.x = 220
					end
					c2.y = 0.25*c1.y + 0.75*c2.y
				end
			end
		end
	end
	
	--draw previous frame boxes 
	gui.drawBox(40-BoxRadius*5-3,70-BoxRadius*5-3,40+BoxRadius*5+2,70+BoxRadius*5+2,0xFF000000, 0x80808080)
	
	for n,cell in pairs(cells) do
		if n > (MemorySize+1)*(Inputs+Outputs) or cell.value ~= 0 then
			local color = math.floor((cell.value+1)/2*256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local opacity = 0xFF000000
			if cell.value == 0 then
				opacity = 0x50000000
			end
			--draw ghost cells for previous frames in memory
			if cell.age then
				opacity = 0x5000000/(2^cell.age)
			end

			color = opacity + color*0x10000 + color*0x100 + color
			gui.drawBox(cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
		end
	end

	--draw prediction frame cells
	gui.drawBox(210-BoxRadius*5-3,70-BoxRadius*5-3,210+BoxRadius*5+2,70+BoxRadius*5+2,0xFF000000, 0x80808080)
	for n,cell in pairs(cells) do
		if n > MaxNodes then
			local color = math.floor((cell.value+1)/2*256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local opacity = 0xFF000000
			if cell.value == 0 then
				opacity = 0x50000000
			end
			color = opacity + color*0x10000 + color*0x100 + color
			gui.drawBox(cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
		end
	end

	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			local opacity = 0xA0000000
			if c1.value == 0 then
				opacity = 0x20000000
			end
			
			local color = 0x80-math.floor(math.abs(sigmoid(gene.weight))*0x80)
			if gene.weight > 0 then 
				color = opacity + 0x8000 + 0x10000*color
			else
				color = opacity + 0x800000 + 0x100*color
			end
			gui.drawLine(c1.x+1, c1.y, c2.x-3, c2.y, color)
		end
	end
	
	gui.drawBox(49,71,51,78,0x00000000,0x80FF0000)
	
	if forms.ischecked(showMutationRates) then
		local pos = 100
		for mutation,rate in pairs(genome.mutationRates) do
			gui.drawText(100, pos, mutation .. ": " .. rate, 0xFF000000, 10)
			pos = pos + 8
		end
	end
end

function writeFile(pool, filename)
        local file = io.open(filename, "w")
	file:write(pool.generation .. "\n")
	file:write(pool.maxFitness .. "\n")
	file:write(pool.memorySize .. "\n")
	file:write(#pool.species .. "\n")
        for n,species in pairs(pool.species) do
		file:write(species.topFitness .. "\n")
		file:write(species.staleness .. "\n")
		file:write(#species.genomes .. "\n")
		for m,genome in pairs(species.genomes) do
			file:write(genome.fitness .. "\n")
			file:write(genome.maxneuron .. "\n")
			for mutation,rate in pairs(genome.mutationRates) do
				file:write(mutation .. "\n")
				file:write(rate .. "\n")
			end
			file:write("done\n")
			
			file:write(#genome.genes .. "\n")
			for l,gene in pairs(genome.genes) do
				file:write(gene.into .. " ")
				file:write(gene.out .. " ")
				file:write(gene.weight .. " ")
				file:write(gene.innovation .. " ")
				if(gene.enabled) then
					file:write("1\n")
				else
					file:write("0\n")
				end
			end
		end
        end
        file:close()
end

function savePool()
	local filename = forms.gettext(saveLoadFile)
	local pool = playpool
	if forms.ischecked(refPred) then
		pool = predpool
	end
	writeFile(pool, filename)
end

function loadFile(filename)
    local file = io.open(filename, "r")
	local pool = newPool()
	pool.generation = file:read("*number")
	pool.maxFitness = file:read("*number")
	pool.memorySize = file:read("*number")
	forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
        local numSpecies = file:read("*number")
        for s=1,numSpecies do
		local species = newSpecies()
		table.insert(pool.species, species)
		species.topFitness = file:read("*number")
		species.staleness = file:read("*number")
		local numGenomes = file:read("*number")
		for g=1,numGenomes do
			local genome = newGenome()
			table.insert(species.genomes, genome)
			genome.fitness = file:read("*number")
			genome.maxneuron = file:read("*number")
			local line = file:read("*line")
			while line ~= "done" do
				genome.mutationRates[line] = file:read("*number")
				line = file:read("*line")
			end
			local numGenes = file:read("*number")
			for n=1,numGenes do
				local gene = newGene()
				table.insert(genome.genes, gene)
				local enabled
				gene.into, gene.out, gene.weight, gene.innovation, enabled = file:read("*number", "*number", "*number", "*number", "*number")
				if enabled == 0 then
					gene.enabled = false
				else
					gene.enabled = true
				end
				
			end
		end
	end
        file:close()
	
    if forms.ischecked(refPred) then
    	predpool = pool
    	while fitnessAlreadyMeasured(predpool) do
			nextGenome(predpool)
		end
		initializeRun()
    else
    	playpool = pool
    	while fitnessAlreadyMeasured(playpool) do
			nextGenome(playpool)
		end
		initializeRun()
    end
    playpool.currentFrame = playpool.currentFrame + 1
end
 
function loadPool()
	local filename = forms.gettext(saveLoadFile)
	loadFile(filename)
end

function playTop()
	local maxfitness = 0
	local maxs, maxg
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end
	
	pool.currentSpecies = maxs
	pool.currentGenome = maxg
	pool.maxFitness = maxfitness
	forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
	return
end

function onExit()
	forms.destroy(form)
end

writeFile(playpool,"temp.pool")

event.onexit(onExit)

form = forms.newform(200, 290, "Fitness")
maxFitnessLabel = forms.label(form, "Max Fitness: " .. math.floor(playpool.maxFitness), 5, 8)
refPred = forms.checkbox(form, "Show Pred", 5, 38)
showNetwork = forms.checkbox(form, "Show Map", 5, 60)
showMutationRates = forms.checkbox(form, "Show M-Rates", 5, 82)
restartButton = forms.button(form, "Restart", initializePool, 5, 107)
saveButton = forms.button(form, "Save", savePool, 5, 132)
loadButton = forms.button(form, "Load", loadPool, 80, 132)
saveLoadFile = forms.textbox(form, Filename .. ".pool", 170, 25, nil, 5, 178)
saveLoadLabel = forms.label(form, "Save/Load:", 5, 159)
playTopButton = forms.button(form, "Play Top", playTop, 5, 205)
hideBanner = forms.checkbox(form, "Hide Banner", 5, 230)


while true do
	local backgroundColor = 0xD0FFFFFF
	if not forms.ischecked(hideBanner) then
		gui.drawBox(0, 0, 300, 26, backgroundColor, backgroundColor)
	end

	local playspecies = playpool.species[playpool.currentSpecies]
	local playgenome = playspecies.genomes[playpool.currentGenome]

	local predspecies = predpool.species[predpool.currentSpecies]
	predgenome = predspecies.genomes[predpool.currentGenome]
	
	if forms.ischecked(showNetwork) then
		if forms.ischecked(refPred) and playpool.currentFrame > 0 then
			displayPredGenome(predgenome)
		else
			displayPlayGenome(playgenome)
		end
	end

	if playpool.currentFrame%5 == 0 then
		evaluateCurrent() 
	end

	joypad.set(controller)

	getPositions()
	if marioX > rightmost then
		rightmost = marioX
		timeout = TimeoutConstant
	end
	
	timeout = timeout - 1
	
	
	local timeoutBonus = playpool.currentFrame / 4

	if timeout + timeoutBonus <= 0 then

		--When time is up, calculate player genome fitness
		local fitness = rightmost - playpool.currentFrame / 2

		--Add fitness bonus for beating the level
		if gameinfo.getromname() == "Super Mario World (USA)" and rightmost > 4816 then
			fitness = fitness + 1000
		end
		if gameinfo.getromname() == "Super Mario Bros. (W) [!]" and rightmost > 3186 then
			fitness = fitness + 1000
		end

		--Make a fitness of 0 less favorable
		if fitness == 0 then
			fitness = -1
		end

		--Log genome fitness in the genome's table
		playgenome.fitness = fitness
		
		--Update maximum fitness when ceiling is broken
		if fitness > playpool.maxFitness then
			playpool.maxFitness = fitness
			forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(playpool.maxFitness))
			writeFile(playpool, "backup." .. playpool.generation .. "." .. forms.gettext(saveLoadFile))
		end
		
		if predgenome.fitness > predpool.maxFitness then
			predpool.maxFitness = predgenome.fitness
			forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(predpool.maxFitness))
			writeFile(predpool, "backup." .. predpool.generation .. "." .. forms.gettext(saveLoadFile))
		end

		--Write out current run statistics
		console.writeline("Gen " .. predpool.generation .. " species " .. predpool.currentSpecies .. " genome " .. predpool.currentGenome .. " fitness: " .. predgenome.fitness)
		playpool.currentSpecies = 1
		playpool.currentGenome = 1

		predpool.currentSpecies = 1
		predpool.currentGenome = 1

		--iterate over play and pred genomes until genome without fitness measurement
		while fitnessAlreadyMeasured(playpool) do
			nextGenome(playpool)
		end
		while fitnessAlreadyMeasured(predpool) do
			nextGenome(predpool)
		end

		initializeRun()
	end

	local measured = 0
	local total = 0
	for _,species in pairs(playpool.species) do
		for _,genome in pairs(species.genomes) do
			total = total + 1
			if genome.fitness ~= 0 then
				measured = measured + 1
			end
		end
	end
	if not forms.ischecked(hideBanner) then
		gui.drawText(0, 0, "Gen " .. playpool.generation .. " species " .. playpool.currentSpecies .. " genome " .. playpool.currentGenome .. " (" .. math.floor(measured/total*100) .. "%)", 0xFF000000, 11)
		gui.drawText(0, 12, "Fitness: " .. math.floor(rightmost - (playpool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3), 0xFF000000, 11)
		gui.drawText(100, 12, "Max Fitness: " .. math.floor(playpool.maxFitness), 0xFF000000, 11)
	end
		
	playpool.currentFrame = playpool.currentFrame + 1

	emu.frameadvance();
end
